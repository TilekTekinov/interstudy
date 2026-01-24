(use /environment /schema)

(def collections/branches
  "All collections provided by the tree"
  [:faculties :semesters :study-programmes :courses])

(def collections/fruits
  "All fruit collections probided by the tree"
  [:registrations :enrollments])

(define-update RefreshView
  "Event that refreshes view"
  [_ {:view view :store store}]
  (def c @[])
  (merge-into
    view
    (:transact store
               (<- c (=> :active-semester))
               (<- c (=> :registrations))
               (<- c (=> :enrollments))
               (<- c (=> :courses (>Y (??? {:active truthy? :semester (?eq (c 0))}))))
               (>base c)
               (>zipcoll [:active-semester :registration :enrollments :active-courses]))))

(defn ^set-active-semester
  "Event that saves active semester into store"
  [semester]
  (make-event
    {:update
     (fn [_ {:store store :view view}]
       (:save store semester :active-semester))
     :watch [RefreshView Flush]}))

(defn ^save-course
  "Event that saves course"
  [code new]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store
                          (=>course/by-code code)
                          (>merge-into new)))
     :watch [RefreshView Flush]}))

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

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:active-semester
      (fn [rpc] (define :view) (view :active-semester))
      :set-active-semester
      (fn [rpc semester]
        (produce (^set-active-semester semester))
        :ok)
      :save-course
      (fn [rpc code new]
        (produce (^save-course code new))
        :ok)
      :save-registration
      (fn [rpc key registration]
        (produce (^save-registration key registration))
        :ok)
      :save-enrollment
      (fn [rpc key enrollment]
        (produce (^save-enrollment key enrollment))
        :ok)}
    (tabseq [coll :in (array/concat @[:active-courses :courses]
                                    collections/branches collections/fruits)]
      coll (fn [rpc] (define :view) (view coll)))))

(def initial-state
  "Configuration"
  ((=> (=>symbiont-initial-state :tree)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     ((>put :view
            (:transact (state :store) (>select-keys ;collections/branches ;collections/fruits)))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn main
  ```
  Main entry into tree.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact PrepareStore PrepareView)
      (:transact RPC)
      :await)
  (os/exit 0))
