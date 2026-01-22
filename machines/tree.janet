(use /environment /schema)

(def collections
  "All collections provided by the tree"
  [:faculties :semesters :study-programmes :courses])

(defn ^set-active-semester
  "Event that saves active semester into store"
  [semester]
  (make-event
    {:update
     (fn [_ {:store store :view view}]
       (:save store semester :active-semester)
       ((>put :active-semester semester) view))
     :watch Flush}))

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:active-semester
      (fn [rpc] (define :view) (view :active-semester))
      :set-active-semester
      (fn [rpc semester]
        (produce (^set-active-semester semester))
        :ok)}
    (tabseq [coll :in (array/concat @[:active-courses] collections)]
      coll (fn [rpc]
             (define :view)
             (view coll)))))

(def initial-state
  "Configuration"
  ((=> (=>machine-initial-state :tree)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def c @[])
     (def view
       (:transact (state :store)
                  (<- c (>select-keys :active-semester))
                  (<- c (=> :courses (>Y (=> :active)) |@{:active-courses $}))
                  (<- c (>select-keys ;collections))
                  (>base c) (>merge)))
     ((>put :view view) state))
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
