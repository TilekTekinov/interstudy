(import /environment :export true :prefix "")
(import /templates/app)
(import /templates/admin)


(setdyn *handler-defines* [:view])

(def admin-page
  "Admin captured"
  (admin/capture))

(defn make/index
  "Creates index handler with `title`"
  [title]
  (fnh /index [appcap]
       [title admin-page]))

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
      (seq [registration :in registrations
            :let [emhash (hash (registration :email))]]
        (<registration/> emhash registration (enrollments emhash)))]]]])

(defh /registrations
  "Registrations SSE stream"
  []
  (ds/hg-stream
    (<registrations-list/> (values (view :registrations)) (view :enrollments))))

(defh /registrations/search
  "Search registrations handler"
  [http/keywordize-body http/json->body]
  (def search (body :search))
  (def =>search
    (=> :registrations
        (>if (always (present? search))
             (=> pairs
                 (>map (=> last (enrich-fuzzy search :email :fullname)))
                 =>filter-sort-score))))
  (ds/hg-stream
    (<registrations-list/> (=>search view) (view :enrollments) true)))

(defn ^prepare-view
  "Initializes view and puts it in the dyn"
  [view-collections]
  (make-event
    {:update
     (fn [_ state]
       (def {:tree tree} state)
       (put state :view
            (tabseq [coll :in view-collections]
              coll (coll tree))))
     :effect (fn [_ {:view view :student student} _]
               (setdyn :view view)
               (setdyn :student student))}))
