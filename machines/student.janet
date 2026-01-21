(use /environment /schema)
(import /machines/tree :only [collections])
(import /templates/app)
(import /templates/registration)
(import /templates/enrollment)

(setdyn *handler-defines* [:view])

(define-effect ConnectTree
  "Connects to the tree"
  [_ state _]
  (setdyn :client
          (rpc/client ;(server/host-port (state :tree))
                      :student (state :psk))))

(define-update RefreshView
  "Refreshes the data in view"
  [_ state]
  (def {:store store} state)
  ((=> :view
       (>put :registrations (:load store :registrations))
       (>put :enrollments (:load store :enrollments))) state))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (define :client)
     ((>put :view
            ((>update :courses (>Y (=> :active)))
              (tabseq [coll :in tree/collections] coll
                (coll client))))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn- hash-email
  [registration]
  (and
    (registration :email)
    (string (util/bin2hex (hash/hash 16 (registration :email) "student0")))))

(defn ^save-registration
  "Event that creates registration in the store"
  [regkey regdata]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store :registrations
                          (>put regkey regdata)))
     :watch [Flush RefreshView]}))

(defn ^save-enrollment
  "Event that creates enrollment in the store"
  [regkey regdata]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store :enrollments
                          (>put regkey regdata)))
     :watch [Flush RefreshView]}))

(defmacro- regcap
  "Convenience for registration template capture"
  [&opt err]
  ~(registration/capture
     ;,(if err ~[:error ,err :registration registration] '[])
     :faculties (view :faculties)
     :study-programmes (view :study-programmes)))

(defh /index
  "Index page."
  [http/html-get]
  (appcap "Registration" (regcap)))

(def- err-msg
  ``
Registration failed.
Please make sure you fill all the fields with correct data.
``)

(defh /register
  "Registration handler"
  [http/html-success http/urlenc-post]
  (def registration
    ((>put :timestamp (os/time)) body))
  (def emhash
    (hash-email registration))
  (appcap
    "Registration"
    (cond
      (and
        (registration :email)
        ((=> :registrations emhash) view))
      (do
        (put registration :email nil)
        (regcap "Registration failed. Email already registered."))
      (registration? registration)
      (do
        (produce (^save-registration emhash registration))
        (string "<h2>Registered</h2><div><a href='/enroll/"
                emhash "'>enroll link</a></div>"))
      (regcap err-msg))))

(defmacro enrcap
  "Convenience for enrollment template capture"
  [&opt err]
  ~(enrollment/capture :id id
                       ;,(if err ~[:error ,err :registration registration] '[])
                       :fullname (registration :fullname)
                       :email (registration :email)
                       :courses (view :courses)
                       :enrollment enrollment))
(defh /enrollment
  "Enrollment handler"
  [http/html-success]
  (def id (params :id))
  (def registration ((=> :registrations id) view))
  (def enrollment ((=> :enrollments id) view))
  (appcap "Enrollment" (enrcap)))

(defh /enroll
  "Enroll handler"
  [http/html-success http/urlenc-post]
  (def id (params :id))
  (def registration ((=> :registrations id) view))
  (def enrollment
    ((>put :timestamp (os/time)) body))
  (appcap "Enrollemnt"
          (if (enrollment? enrollment)
            (do
              (produce (^save-enrollment id enrollment))
              "<h2>Enrolled</h2")
            (enrcap "Not enrolled. All courses must be unique."))))
(def routes
  "Application routes"
  @{"/" (http/dispatch {"GET" /index
                        "POST" /register})
    "/enroll/:id" (http/dispatch {"GET" /enrollment
                                  "POST" /enroll})})

(def initial-state
  "Initial state"
  ((=> (=>machine-initial-state :student true)
       (>put :routes routes)) compile-config))

(defn main
  ```
  Main entry into student machine.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact ConnectTree PrepareView PrepareStore)
      (:transact HTTP)
      :await)
  (os/exit 0))
