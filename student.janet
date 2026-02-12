(use /environment /schema)
(import ./tree :only [collections])
(import /templates/registration)
(import /templates/enrollment)

(setdyn *handler-defines* [:view])

(def max-credits "Maximal amount of credits" 30)

(define-update RefreshView
  "Refreshes the data in view"
  [_ {:view view :tree tree}]
  ((=> (>put :registrations (:registrations tree))
       (>put :enrollments (:enrollments tree)))
    view))

(def collections
  "View collections"
  [:faculties :active-courses :semesters])

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     (def {:tree tree} state)
     ((>put :view (tabseq [coll :in collections] coll (coll tree)))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn ^save-registration
  "Event that creates registration in the tree"
  [regkey regdata]
  (make-event
    {:update (fn [_ {:tree tree :view view}]
               ((=> :registrations (>put regkey regdata)) view)
               (:save-registration tree regkey regdata))
     :watch RefreshView}))

(defn ^save-enrollment
  "Event that creates enrollment in the tree"
  [regkey enrdata]
  (make-event
    {:update
     (fn [_ {:tree tree :view view}]
       ((=> :enrollments (>put regkey enrdata)) view)
       (:save-enrollment tree regkey enrdata))
     :watch RefreshView}))

(defmacro- regcap
  "Convenience for registration template capture"
  [&opt err]
  ~(registration/capture
     ;,(if err ~[:error ,err :registration registration] '[])
     :faculties (view :faculties)))

(defh /index
  "Index page."
  [appcap]
  (if-not (empty? (view :active-courses))
    ["Registration" (regcap)]))

(defn- err-msg
  [reason]
  (string "Registration failed. " reason))

(defh /register
  "Registration handler"
  [appcap http/urlenc-post]
  (def registration (>stamp body))
  (def {:email email} registration)
  (def emhash (hash email))
  ["Registration"
   (cond
     (and
       (registration :email)
       ((=> :registrations emhash) view))
     (do
       (put registration :email nil)
       (regcap (err-msg "Email already registered.")))
     (registration? registration)
     (do
       (produce (^save-registration emhash registration))
       (string "<h2>Registered</h2><div><a href='/enroll/"
               emhash "'>enroll link</a></div>"))
     (regcap (err-msg "Please make sure you fill all the fields with correct data.")))])

(defmacro enrcap
  "Convenience for enrollment template capture"
  [&opt err]
  ~(enrollment/capture
     :id id
     ;,(if err ~[:error ,err :registration registration] '[])
     :fullname (registration :fullname)
     :email (registration :email)
     :courses (view :active-courses)
     :enrollment enrollment))

(defn <enrollment-form/>
  "htmlgen representation of the enrollment form"
  [registration enrollment courses &opt err]
  (def credits (get enrollment :credits 0))
  (def add-empty (and (not (present? err)) (< credits max-credits)))
  (def ec
    ((=> :courses (>if (always add-empty) |[;$ ""])) enrollment))
  (def tabcourses
    (tabseq [[i v] :pairs ec] (keyword "course-" i) v))
  (def options
    @[[:option {:value ""} "-- please choose course --"]
      (seq [{:code code :name name :credits credits} :in courses]
        [:option {:value code} (string/format "%s (%i) %s" code credits name)])])
  (def post-change (ds/post "/enroll/" (hash (registration :email))))
  [:div {:id "enrollment-form"}
   [:h2 "Student: " (registration :fullname) " <" (registration :email) ">"]
   [:h3 "Credits: " credits " of " max-credits]
   (if (present? err)
     [:div {:class "warn box"}
      (seq [e :in err :when (present? e) :let [[field reason] (kvs e)]]
        (case field
          :credits [:div "Credit limit exceeded"]
          :courses [:div "Courses must be unique"]))]
     (if (not= 0 credits)
       [:div {:class "ok box"}
        "Your enrollment was saved. You can leave this page and return later."]))
   [:form {:class "table rows"
           :data-signals (json/encode tabcourses)}
    [:div [:span "Legend"] [:span "code"] [:span "(credits)"] [:span "name"]]
    (seq [[i course] :pairs ec
          :let [name (keyword "course-" i)
                label (string "Course " (inc i))]]
      [:p
       [:label {:for name} label]
       [:select
        {:name name :id name :data-bind name
         :data-on:change post-change}
        options]
       (if (present? (tabcourses name))
         [:a {:data-on:click
              (string "$" name " = '';" post-change)}
          "Remove"])])]])

(defh /enrollment
  "Enrollment handler"
  [appcap]
  (def id (params :id))
  (when-let [registration ((=> :registrations id) view)
             courses ((??? present?) (view :active-courses))]
    (def enrollment
      ((=> :enrollments (>if (=> id) (=> id) (always @{:courses @[]}))) view))
    ["Enrollment"
     (hg/html (<enrollment-form/> registration enrollment
                                  courses))]))

# TODO view credit index
(defn sum-credits
  "Sums all credit from enrollment"
  [enrcourses courses]
  (when (present? enrcourses)
    (var sum 0)
    (each code enrcourses
      ((=> (>find-from-start (??? {:code (?eq code) :credits number?}))
           (>if (=> :credits) (=> :credits |(+= sum $)))) courses))
    sum))

(def =>coerce-body
  "Navigation that coerces body courses table to enrollment array"
  (=> pairs (>sort-by first) (>map last) (>Y present?)))

(defh /enroll
  "Enroll handler"
  [http/keywordize-body http/json->body]
  (if-let [id (params :id)
           registration ((=> :registrations id) view)
           courses (=>coerce-body body)]
    (let [credits (sum-credits courses (view :active-courses))
          enrollment (>stamp @{:credits credits :courses courses})]
      (ds/hg-stream
        (<enrollment-form/>
          registration enrollment (view :active-courses)
          (if (enrollment? enrollment)
            (produce (^save-enrollment id enrollment))
            (enrollment! enrollment)))))
    (http/not-found)))

(def routes
  "Application routes"
  @{"/" (http/dispatch {"GET" /index
                        "POST" /register})
    "/enroll/:id" (http/dispatch {"GET" /enrollment
                                  "POST" /enroll})})

(defr +:refresh
  "RPC function, that refreshes the view"
  [produce-resp ok-resp]
  (def [what] args)
  (case what
    :active-semester
    (produce (^refresh-view :active-courses :active-semester))
    :courses
    (produce (^refresh-view :active-courses :courses))
    (produce (^refresh-view what))))

(def rpc-funcs
  "RPC functions"
  @{:refresh +:refresh
    :stop close-peers-stop})

(def initial-state
  "Initial state"
  ((=> (=>symbiont-initial-state :student)
       (>put :routes routes)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(define-watch Start
  "Starts the machinery"
  [&]
  [PrepareView (^register :tree)
   HTTP RPC Ready])

(defn main
  ```
  Main entry into student symbiont.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact (^connect-peers Start Exit))
      :await)
  (os/exit 0))
