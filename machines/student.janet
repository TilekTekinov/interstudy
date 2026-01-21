(use /environment /schema)
(import /machines/tree :only [collections])
(import /templates/app)
(import /templates/registration)

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
  ((=> :view (>put :registrations (:load store :registrations))) state))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (define :client)
     ((>put :view
            (tabseq [coll :in tree/collections] coll
              (coll client)))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn ^create-registration
  "Event that creates registration in the store"
  [regdata]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store :registrations
                          (>put (regdata :email) regdata)))
     :watch [Flush RefreshView]}))

(defmacro- regcap
  [&opt err]
  ~(registration/capture
     ;,(if err ~[:error ,err] '[])
     :faculties (view :faculties)
     :study-programmes (view :study-programmes)))

(defh /index
  "Index page."
  [http/html-get]
  (app/capture :title "Registration"
               :content
               (regcap)))

(def- err-msg
  ``
Registration failed.
Please make sure you fill all the fields with correct data.
``)

(defh /registration
  "Registration handler"
  [http/html-success http/urlenc-post]
  (def registration
    ((=> (>map-keys keyword)
         (>put :timestamp (os/time))) body))
  (app/capture
    :title "Registration"
    :content
    (cond
      ((=> :registrations (registration :email)) view)
      (regcap "Registration failed. Email already registered.")
      (registration? registration)
      (do
        (produce (^create-registration registration))
        "<h1>Registered</h1>")
      (regcap err-msg))))

(def routes
  "Application routes"
  @{"/" (http/dispatch {"GET" /index
                        "POST" /registration})})

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
