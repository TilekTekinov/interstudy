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
     (def {:store store :client client} state)
     ((=> (>put :view (tabseq [coll :in collections] coll (coll client)))
          :view (>put :active-semester (:load store :active-semester)))
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

(defn <semesters-list/>
  "Contructs htmlgen representation of all `semesters`"
  [active-semester semesters]
  @[[:details {:open "true"}
     [:summary "Semesters"]
     [:table
      [:thead
       [:tr [:th "name"] [:th "active"] [:th "action"]]]
      [:tbody
       (seq [semester :in semesters :let [active? (= semester active-semester)]]
         [:tr
          [:td semester]
          [:td (if active? "x")]
          [:td
           (if-not active?
             [:a {:data-on:click (ds/get "/semesters/activate/" semester)}
              "Activate"])]])]]]])

(defh /semesters
  "Semesters SSE stream"
  []
  (http/stream
    (ds/element "div#semesters" (hg/html (<semesters-list/> (view :active-semester)
                                                            (view :semesters))))))

(define-update RefreshView
  "Refreshes the data in view"
  [_ state]
  (def {:store store} state)
  ((=> :view
       (>put :active-semester (:load store :active-semester)))
    state))

(defn ^activate
  "Events that activates semester"
  [semester]
  (make-event
    {:update (fn [_ {:store store}]
               (:save store semester :active-semester))
     :watch [Flush RefreshView]}))

(defh /activate
  "Semesters SSE stream"
  []
  (def semester (params :semester))
  (produce (^activate semester))
  (http/stream
    (ds/element "div#semesters"
                (hg/html (<semesters-list/> semester
                                            (view :semesters))))))

(def routes
  "HTTP routes"
  @{"/" /index
    "/courses" /courses
    "/semesters" @{"" /semesters
                   "/activate/:semester" /activate}})

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
