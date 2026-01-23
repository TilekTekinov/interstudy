(use /environment /schema)
(import /templates/app)
(import /templates/admin)
(import /templates/course-form)

(setdyn *handler-defines* [:view])

(def collections
  "View collections"
  [:faculties :study-programmes :semesters])

(defn ^refresh
  "Refreshes the data in view"
  [& colls]
  (make-update
    (fn [_ state]
      (def {:client client :view view} state)
      (each coll colls
        ((>put coll (coll client))
          view)))))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:client client} state)
     ((>put :view (tabseq [coll :in collections] coll (coll client)))
       state))
   :watch (^refresh :active-semester :courses)
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defh /index
  "Index page"
  [http/html-get]
  (appcap "Admin" (admin/capture)))

(defn <course/>
  "Contructs htmlgen representation of one `course`"
  [{:code code :name name :credits credits
    :active active}]
  [:tr {:id code}
   [:td code]
   [:td name]
   [:td credits]
   [:td (if active "x")]
   [:td
    [:a {:data-on:click (string "@get('/courses/edit/" code "')")}
     "Edit"]]])

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
         (<course/> course))]]]])

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
     :watch (^refresh :active-semester)}))

(defh /activate
  "Semesters SSE stream"
  []
  (def semester (params :semester))
  (produce (^activate semester))
  (http/stream
    (ds/element "div#semesters"
                (hg/html (<semesters-list/> semester
                                            (view :semesters))))))

(defh /edit-course
  "Edit course SSE stream"
  []
  (def code (params :code))
  (def subject ((=> :courses (>Y (??? {:code (?eq code)})) 0) view))
  (http/stream
    (ds/element
      "div#course-form"
      (string/replace-all "\n" "" (course-form/capture :subject subject)))))

(defn ^save-course
  "Event that saves the course"
  [code course]
  (make-event
    {:effect (fn [_ {:client client} _]
               (:save-course client code course))
     :watch (^refresh :courses)}))

(defh /save-course
  "Save course"
  [http/urlenc-post]
  (def code (get params :code))
  (def active (get body :active false))
  (def course ((=> (=>course/by-code code) (>put :active active)) view))
  (produce (^save-course code course))
  (http/stream
    (ds/element "div#course-form" "<h2>Saving</h2>")
    (ds/patch-elements (hg/html (<course/> course)))
    (ds/element "div#course-form" "")))

(def routes
  "HTTP routes"
  @{"/" /index
    "/courses" @{"" /courses
                 "/edit/:code" /edit-course
                 "/:code" /save-course}
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
      (:transact ConnectTree PrepareView)
      (:transact HTTP)
      :await)
  (os/exit 0))
