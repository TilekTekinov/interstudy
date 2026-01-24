(use /environment /schema)
(import ./tree :only [collections])
(import /templates/app)
(import /templates/registration)
(import /templates/enrollment)

(setdyn *handler-defines* [:view])

(define-update RefreshView
  "Refreshes the data in view"
  [_ {:view view :tree tree}]
  ((=> (>put :registrations (:registrations tree))
       (>put :enrollments (:enrollments tree)))
    view))

(def collections
  "View collections"
  [:faculties :active-courses :study-programmes :semesters])

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:tree tree} state)
     ((>put :view (tabseq [coll :in collections] coll (coll tree)))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn ^save-registration
  "Event that creates registration in the tree"
  [regkey regdata]
  (make-event
    {:update (fn [_ {:tree tree :view view}]
               ((=> :registrations (>put regkey regdata)) view)
               (:save-registration tree regkey regdata))
     :watch RefreshView}))

(defn ^save-enrollment
  "Event that creates enrollment in the tree"
  [regkey enrdata]
  (make-event
    {:update
     (fn [_ {:tree tree :view view}]
       ((=> :enrollments (>put regkey enrdata)) view)
       (:save-enrollment tree regkey enrdata))
     :watch RefreshView}))

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

(defn- err-msg
  [reason]
  (string "Registration failed. " reason))

(defh /register
  "Registration handler"
  [http/html-success http/urlenc-post]
  (def registration (>stamp body))
  (def {:email email} registration)
  (def emhash (hash email))
  (appcap
    "Registration"
    (cond
      (and
        (registration :email)
        ((=> :registrations emhash) view))
      (do
        (put registration :email nil)
        (regcap (err-msg "Email already registered.")))
      (registration? registration)
      (do
        (produce (^save-registration emhash registration))
        (string "<h2>Registered</h2><div><a href='/enroll/"
                emhash "'>enroll link</a></div>"))
      (regcap (err-msg "Please make sure you fill all the fields with correct data.")))))

(defmacro enrcap
  "Convenience for enrollment template capture"
  [&opt err]
  ~(enrollment/capture
     :id id
     ;,(if err ~[:error ,err :registration registration] '[])
     :fullname (registration :fullname)
     :email (registration :email)
     :courses (view :active-courses)
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
  (def enrollment (>stamp body))
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
  ((=> (=>symbiont-initial-state :student true)
       (>put :routes routes)) compile-config))

(defn main
  ```
  Main entry into student symbiont.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact (^connect-tree [PrepareView HTTP]))
      :await)
  (os/exit 0))
