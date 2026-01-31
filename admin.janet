(use /environment /schema)
(import gp/data/fuzzy)
(import /templates/app)
(import /templates/admin)

(setdyn *handler-defines* [:view])

(def collections
  "View collections"
  [:faculties :semesters :registrations :enrollments])

(define-update RecomputeIndices
  "Recomputes indices in view"
  [_ {:view view}]
  (def c @[])
  ((=>
     (<- c (=> :enrollments values (>: :courses) flatten frequencies))
     |(put $ :enrolled-index (array/pop c))) view))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:tree tree} state)
     ((=> (>put :view (tabseq [coll :in collections] coll (coll tree))))
       state))
   :watch [(^refresh-view :active-semester :courses)
           RecomputeIndices]
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
    :semester semester :active active :enrolled enrolled}]
  [:tr {:id code}
   [:td code]
   [:td name]
   [:td credits]
   [:td semester]
   [:td {:class :active} (if active "x")]
   [:td
    (if enrolled
      [:a {:data-on:click (ds/get "/courses/enrolled/" code)}
       [:span (length enrolled) (hg/raw "&nbsp;enrolled")]])]
   [:td
    [:a {:data-on:click (ds/get "/courses/edit/" code)}
     "Edit"]]])

(def- init-ds (json/encode {:active false :semester "" :enrolled false}))

(defn <courses-list/>
  "Contructs htmlgen representation of all `courses`"
  [courses &opt open]
  [:div {:id "courses"
         :data-bind init-ds}
   [:details (if open {:open true})
    [:summary
     "Courses (" (length courses) ")"]
    [:div {:class "margin-block"}
     (ds/input
       :search :type :search :size 50
       :placeholder "Search in the course code and name"
       :data-on:input__debounce.200ms
       (string "$active = false; $enrolled = false; $semester = ''; "
               (ds/post "/courses/search")))]
    [:div {:class "f-row margin-block"}
     "Filter: "
     [:label "Only active "
      (ds/input :active :type :checkbox
                :data-on:change (ds/get "/courses/filter/"))]
     [:label "Only enrolled "
      (ds/input :enrolled :type :checkbox
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
       [:th "semester"] [:th "active"] [:th "enrolled"] [:th "action"]]]
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
    [:button {:data-on:click (ds/post "/courses/save" code)} "Save"]]])

(defh /edit-course
  "Edit course SSE stream"
  []
  (def code (params :code))
  (def subject ((=>course/by-code code) view))
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
   [:td [:small (if ts (dt/format-date-time ts))]]
   [:td {:class "f-coll"}
    (if ets
      [:small
       [:div (dt/format-date-time ets) " "]
       [:div (length ecs) " for " ecr " credits"]])
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

(defh /registrations/search
  "Search registrations handler"
  [http/keywordize-body http/json->body]
  (def search (body :search))
  (def =>search
    (=> :registrations
        (>if (always (present? search))
             (=> pairs
                 (>map (=> last (enrich-fuzzy search :email :fullname)))
                 =>filter-sort-score
                 (>map |(table (hash ($ :email)) $)) (>merge)))))
  (ds/hg-stream
    (<registrations-list/> (=>search view) (view :enrollments) true)))

(def?! filterable (?one-of "semester" "active" "enrolled"))

(defh /filter
  "Filtered courses SSE stream"
  [http/query-params]
  (def finders
    ((=> :query-params "datastar"
         (>if present? json/decode (always {})) pairs
         (>Y (>check-all all
                         (=> first filterable?)
                         (=> last (>check-all some true? present?))))
         (>map (fn [[k v]] (>Y (=> (??? {(keyword k)
                                         (if (true? v) truthy? (?eq v))}))))))
      req))
  (ds/hg-stream
    (<courses-list/> ((=> :courses ;finders) view) true)))

(defn <enrolled/>
  "hg representation of enrolled students"
  [code enrolled]
  [:tr {:id (string code "-enrolled")}
   [:td {:colspan "7"}
    [:ul
     (seq [{:fullname fn :email em} :in enrolled]
       [:li fn " <" em ">"])]]])

(defh /enrolled
  "Enrolled students for a course detail"
  []
  (def code (params :code))
  (def c @[])
  (def enrolled
    ((=> (<- c (=> :registrations))
         (=>course/by-code code) :enrolled
         (>reduce (fn [acc id] (array/push acc ((c 0) id)) acc) @[])) view))
  (ds/hg-stream (<enrolled/> code enrolled) (string "#" code) "after"))

(defh /courses/search
  "Search courses handler"
  [http/keywordize-body http/json->body]
  (def search (body :search))
  (def =>search
    (=> :courses
        (>if (always (present? search))
             (=> pairs
                 (>map (=> last (enrich-fuzzy search :code :name)))
                 =>filter-sort-score))))
  (ds/hg-stream (<courses-list/> (=>search view) true)))

(def routes
  "HTTP routes"
  @{"/" /index
    "/registrations" @{"" /registrations
                       "/activate/:registration" /activate
                       "/deactivate" /deactivate
                       "/search" /registrations/search}
    "/semesters" @{"" /semesters
                   "/activate/:semester" /activate
                   "/deactivate" /deactivate}
    "/courses" @{"" /courses
                 "/edit/:code" /edit-course
                 "/save/:code" /save-course
                 "/filter/" /filter
                 "/enrolled/:code" /enrolled
                 "/search" /courses/search}})

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
