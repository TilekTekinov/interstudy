(use /environment /schema)
(import /templates/app)
(import /templates/admin)

(setdyn *handler-defines* [:view])

(def collections
  "View collections"
  [:faculties :courses :study-programmes :semesters])

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:client client} state)
     ((>put :view (tabseq [coll :in collections] coll (coll client)))
       state))
   :watch CloseTree
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defh /index
  "Index page"
  [http/html-get]
  (appcap "Admin" (admin/capture)))

(defn <courses-list/>
  "Contructs htmlgen representation of all `courses`"
  [courses]
  @[[:details {:open "true"}
     [:summary "Courses (" (length courses) ")"]
     [:table
      [:thead
       [:tr [:th "code"] [:th "name"] [:th "credits"]
        [:th "active"] [:th "action"]]]
      [:tbody
       (seq [course :in courses]
         [:tr
          [:td (course :code)]
          [:td (course :name)]
          [:td (course :credits)]
          [:td (if (course :active) "x")]
          [:td
           [:a {:data-on:click (string "@get('/courses/edit/" (course :code) "')")}
            "Edit"]]])]]]])

(defh /courses
  "Courses SSE stream"
  []
  (http/stream
    (ds/element "div#courses" (hg/html (<courses-list/> (view :courses))))))

(def routes
  "HTTP routes"
  @{"/" /index
    "/courses" /courses})

(def initial-state
  "Initial state"
  ((=> (=>machine-initial-state :admin true)
       (>put :routes routes)) compile-config))

(defn main
  ```
  Main entry into student machine.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact ConnectTree PrepareStore)
      (:transact PrepareView)
      (:transact HTTP)
      :await)
  (os/exit 0))
