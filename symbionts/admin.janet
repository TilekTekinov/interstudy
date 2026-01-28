(use /environment /schema)
(import gp/data/fuzzy)
(import /templates/app)
(import /templates/admin)

(setdyn *handler-defines* [:view])

(def collections
  "View collections"
  [:faculties :semesters :registrations :enrollments])

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:tree tree} state)
     ((=> (>put :view (tabseq [coll :in collections] coll (coll tree))))
       state))
   :watch (^refresh-view :active-semester :courses)
   :effect (fn [_ {:view view :student student} _]
             (setdyn :view view)
             (setdyn :student student))})

(def admin-page
  "Admin captured"
  (admin/capture))

(defh /index
  "Index page"
  [appcap]
  ["Admin" admin-page])

(defn <course/>
  "Contructs htmlgen representation of one `course`"
  [{:code code :name name :credits credits
    :semester semester :active active}]
  [:tr {:id code}
   [:td code]
   [:td name]
   [:td credits]
   [:td semester]
   [:td {:class :active} (if active "x")]
   [:td
    [:a {:data-on:click (string "@get('/courses/edit/" code "')")}
     "Edit"]]])

(defn <courses-list/>
  "Contructs htmlgen representation of all `courses`"
  [courses &opt open]
  [:div {:id "courses" :data-bind (json/encode {:active false :semester false})}
   [:details (if open {:open true})
    [:summary
     "Courses (" (length courses) ")"]
    [:div {:class "f-row margin-block"}
     "Filter: "
     [:label "Only active "
      (ds/input :active :type :checkbox
                :data-on:change (ds/get "/courses/filter/"))]
     [:label "Only Winter semester "
      (ds/input :semester :type :checkbox :value "Winter"
                :data-on:change (ds/get "/courses/filter/"))]
     [:label "Only Summer semester "
      (ds/input :semester :type :checkbox :value "Summer"
                :data-on:change (ds/get "/courses/filter/"))]]
    [:table
     [:thead
      [:tr [:th "code"] [:th {:class :name} "name"] [:th "credits"]
       [:th "semester"] [:th "active"] [:th "action"]]]
     [:tbody (seq [course :in courses] (<course/> course))]]]])

(defh /courses
  "Courses SSE stream"
  []
  (ds/hg-stream (<courses-list/> (view :courses))))

(defn <semesters-list/>
  "Contructs htmlgen representation of all `semesters`"
  [active-semester semesters &opt open]
  [:div {:id "semesters"}
   [:details (if open {:open true})
    [:summary "Semesters"]
    [:a {:data-on:click (ds/get "/semesters/deactivate")}
     "Deactivate"]
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
  (ds/hg-stream
    (<semesters-list/> (view :active-semester)
                       (view :semesters))))

(defn ^activate
  "Events that activates semester"
  [semester]
  (make-event
    {:effect (fn [_ {:tree tree :view view} _]
               ((>put :active-semester semester) view)
               (:set-active-semester tree semester))
     :watch (^refresh-view :active-semester)}))

(defh /activate
  "Semesters SSE stream"
  []
  (def semester (params :semester))
  (produce (^activate semester))
  (ds/hg-stream (<semesters-list/> semester (view :semesters) true)))

(defn <course-form/>
  "Course form hg representation"
  [course semesters]
  (def {:code code} course)
  [:tr {:id code :data-signals (json/encode course)}
   [:td code]
   [:td (ds/input :name :type "text" :size 40)]
   [:td (ds/select :credits
                   (seq [c :range [1 6]] [:option c]))]
   [:td
    (ds/select :semester (seq [s :in semesters] [:option s]))]
   [:td
    (ds/input :active :type "checkbox")]
   [:td
    [:button {:data-on:click (ds/post "/courses/" code)} "Save"]]])

(defh /edit-course
  "Edit course SSE stream"
  []
  (def code (params :code))
  (def subject ((=> :courses (>Y (??? {:code (?eq code)})) 0) view))
  (ds/hg-stream (<course-form/> subject (view :semesters))))

(defn ^save-course
  "Event that saves the course"
  [code course]
  (make-event
    {:effect (fn [_ {:tree tree} _]
               (:save-course tree code course))
     :watch (^refresh-view :courses)}))

(defh /save-course
  "Save course"
  [http/keywordize-body http/json->body]
  (def code (get params :code))
  (def course
    ((=> (=>course/by-code code)
         (>merge-into body)) view))
  (produce (^save-course code course))
  (ds/hg-stream (<course/> course)))

(define-event Deactivate
  "Events that deactivates semester"
  {:effect (fn [_ {:tree tree} _]
             (:set-active-semester tree false))
   :watch (^refresh-view :active-semester)})

(defh /deactivate
  "Deactivation handler"
  []
  (produce Deactivate)
  (ds/hg-stream (<semesters-list/> false (view :semesters) true)))

(defn <registration/>
  "Contructs htmlgen representation of one `registration`"
  [emhash
   {:fullname fn :email em :home-university hu :faculty fa :timestamp ts}
   enrollment]
  (define :student)
  (def {:courses ecs :timestamp ets :credits ecr} (or enrollment {}))
  [:tr {:id emhash}
   [:td fn] [:td em] [:td hu] [:td fa]
   [:td (if ts (dt/format-date-time ts))]
   [:td {:class "f-coll"}
    (if ets
      [:div (dt/format-date-time ets) " "
       (length ecs) " for " ecr " credits"])
    [:a {:href (string student "/enroll/" (hash em))
         :target "_blank"} "Enroll link"]]])

(defn <registrations-list/>
  "Contructs htmlgen representation of all `registrations`"
  [registrations enrollments &opt open]
  [:div {:id "registrations"}
   [:details (if open {:open true})
    [:summary
     "Registrations (" (length registrations) ")"]
    [:div {:class "margin-block"}
     (ds/input
       :search :type :search :size 50
       :placeholder "Search in email and fullname"
       :data-on:input__debounce.200ms (ds/post "/registrations/search"))]
    [:table
     [:thead
      [:tr [:th "Fullname"] [:th "Email"]
       [:th "Home University"] [:th "Faculty"]
       [:th "Registered"] [:th "Enrollment"]]]
     [:tbody
      (seq [[emhash registration] :pairs registrations]
        (<registration/> emhash registration (enrollments emhash)))]]]])

(defh /registrations
  "Registrations SSE stream"
  []
  (ds/hg-stream
    (<registrations-list/> (view :registrations) (view :enrollments))))

(defh /search
  "Search registrations handler"
  [http/keywordize-body http/json->body]
  (def search (body :search))
  (def =>search
    (=> :registrations pairs
        (>Y (=> last |(string ($ :fullname) ($ :email)) |(fuzzy/hasmatch search $)))
        (>map |(table ;$)) (>merge)))
  (ds/hg-stream
    (<registrations-list/>
      (if (present? search) (=>search view) (view :registrations))
      (view :enrollments) true)))

(defh /filter
  "Filtered courses SSE stream"
  [http/query-params]
  (def finders
    ((=> :query-params "datastar"
         (>if present? json/decode (always {})) pairs
         (>Y (>check-all all
                         (=> first (?one-of "semester" "active"))
                         (=> last (>check-all some true? present?))))
         (>map (fn [[k v]] (>Y (=> (??? {(keyword k) (?eq v)})))))) req))
  (ds/hg-stream
    (<courses-list/> ((=> :courses ;finders) view) true)))

(def routes
  "HTTP routes"
  @{"/" /index
    "/registrations" @{"" /registrations
                       "/activate/:registration" /activate
                       "/deactivate" /deactivate
                       "/search" /search}
    "/semesters" @{"" /semesters
                   "/activate/:semester" /activate
                   "/deactivate" /deactivate}
    "/courses" @{"" /courses
                 "/edit/:code" /edit-course
                 "/:code" /save-course
                 "/filter/" /filter}})

(def rpc-funcs
  "RPC functions"
  @{:refresh (fn [_ & what] (produce (^refresh-view ;what)) :ok)})

(def initial-state
  "Initial state"
  ((=> (=>symbiont-initial-state :admin)
       (>put :routes routes)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(defn main
  ```
  Main entry into student symbiont.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact (^connect-peers PrepareView HTTP RPC))
      :await)
  (os/exit 0))
