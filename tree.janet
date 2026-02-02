(use /environment /schema)

(def collections/leafs
  "All collections provided by the tree"
  [:faculties :semesters :courses])

(def collections/fruits
  "All fruit collections probided by the tree"
  [:active-semester :registrations :enrollments])

(define-update RefreshView
  "Event that refreshes view"
  [_ {:view view :store store}]
  (def t @{})
  (merge-into
    view
    (:transact
      store
      (<:= t (>select-keys ;collections/fruits))
      (<:- t :enrollents-index
           (=> :enrollments pairs
               (>reduce
                 (fn [acc [id {:courses cs}]]
                   (each c cs
                     (if-let [ac (acc c)]
                       (array/push ac id)
                       (put acc c @[id]))) acc)
                 @{})))
      :courses values
      (<:- t :courses
           (>map
             (fn [course]
               (put course :enrolled
                    ((t :enrollents-index) (course :code))))))
      (<:- t :active-courses
           (>Y (??? {:active truthy? :semester (?eq (t :active-semester))})))
      (>base t))))

(defn ^refresh-peers
  "Events that sends :refresh to `peer`"
  [what]
  (make-effect
    (fn [_ state _]
      (def {:peers peers} state)
      (each peer peers (:refresh (state peer) what)))))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     ((>put :view
            (:transact (state :store)
                       (>select-keys ;collections/leafs)))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn ^set-active-semester
  "Event that saves active semester into store"
  [semester]
  (make-event
    {:update
     (fn [_ {:store store :view view}]
       (:save store semester :active-semester))
     :watch [RefreshView Flush
             (^refresh-peers :active-semester)]}))

(defn ^save-course
  "Event that saves course"
  [code new]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store
                          :courses code
                          (>merge-into new)))
     :watch [RefreshView Flush (^refresh-peers :courses)]}))

(defn ^save-registration
  "Event that creates registration in the store"
  [regkey regdata]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store :registrations
                          (>put regkey regdata)))
     :watch [Flush RefreshView (^refresh-peers :registrations)]}))

(defn ^save-enrollment
  "Event that creates enrollment in the store"
  [regkey regdata]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store :enrollments
                          (>put regkey regdata)))
     :watch [Flush RefreshView (^refresh-peers :enrollments)
             (^refresh-peers :courses)]}))

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:active-semester
      (fn [rpc] (define :view) (print "fnnnnnn") (view :active-semester))
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
                                    collections/leafs collections/fruits)]
      coll (fn [rpc] (define :view) (view coll)))))

(def =>initial-state
  "Navigation to initial state in config"
  (=> (=>symbiont-initial-state :tree)
      (>update :rpc (update-rpc rpc-funcs))))

(defn main
  ```
  Main entry into tree.
  ```
  [_]
  (-> compile-config
      =>initial-state
      (make-manager on-error)
      (:transact PrepareStore PrepareView)
      (:transact RPC)
      (:transact (^connect-peers (log "Tree is ready")))
      :await)
  (os/exit 0))
