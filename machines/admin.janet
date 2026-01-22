(use /environment /schema)
(import /templates/app)
(import /templates/admin)

(setdyn *handler-defines* [:view])

(def collections
  "View collections"
  [:faculties :courses :study-programmes :semesters])

(define-update RefreshView
  "Refreshes the data in view"
  [_ state]
  (def {:client client :view view} state)
  ((>put :active-semester (:active-semester client))
    view))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:client client} state)
     ((>put :view (tabseq [coll :in collections] coll (coll client)))
       state))
   :watch RefreshView
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

(defn ^activate
  "Events that activates semester"
  [semester]
  (make-event
    {:effect (fn [_ {:client client} _]
               (:set-active-semester client semester))
     :watch RefreshView}))

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
      (:transact ConnectTree PrepareView HTTP)
      :await)
  (os/exit 0))
