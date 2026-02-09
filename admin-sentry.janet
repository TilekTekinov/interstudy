(use /environment /schema)
(import /templates/auth-form)
(import /templates/redirect)

(setdyn *handler-defines* [:view :conn])
(defdyn *view* "View for handlers")

(def =>header-cookie
  "Navigate to cookie in request headers"
  (=> :headers "Cookie" "session"))

(def <form/>
  "Rendered form"
  (http/html-success-resp (auth-form/capture)))

(defn ^write-spawn
  "Writes the spawn command to stdout"
  [sk]
  (make-effect
    (fn [_ {:dry dry} _]
      (unless dry
        (:write stdout (marshal [:admin sk]))
        (:flush stdout)))
    "write spawn"))

(defn derive-from
  "Derives new key from master `key`"
  [key]
  (->> key
       (kdf/derive-from-key 16 (os/time) "track123")
       util/bin2hex
       freeze))

(defh /index
  "Handler for the form"
  [http/cookies]
  <form/>)

(def redirect-page
  "Rendered redirect"
  (redirect/capture :location "/"))

(defh /auth
  "Authentication handler"
  [http/urlenc-post]
  (if-let [sec (view :secret)
           bsec (get body :secret "")
           {:cookie-host cookie-host :key key} view
           _ (pwhash/verify sec bsec key)]
    (let [sk (derive-from key)]
      (fn [conn]
        (:write conn
                (http/success
                  redirect-page
                  (merge (http/content-type ".html")
                         (http/cookie "session"
                                      (string sk "; Secure; HttpOnly; Domain="
                                              cookie-host ";")))))
        (ev/give-supervisor :close conn)
        (produce (^write-spawn sk) Exit)))
    (http/html-success-resp
      (auth-form/capture :error "<h2>Authentication failed</h2>"))))

(defh /catch-all
  "Handler which catches all paths and redirects to form"
  []
  (match [(req :method) (req :uri)]
    ["POST" u] (/auth req)
    ["GET" (u (string/find "." u))]
    ((http/static (view :public)) req)
    ["GET" u] (/index req)))

(def routes
  "HTTP routes"
  @{"/" (http/dispatch {"GET" /index
                        "POST" /auth})
    :not-found /catch-all})

(define-event PrepareView
  "Initializes handlers' view"
  {:update
   (fn [_ state]
     (put state :view
          @{:session (state :session)
            :secret (state :secret)
            :key (state :key)
            :public (state :public)
            :cookie-host (state :cookie-host)}))
   :effect
   (fn [_ state _] (setdyn *view* (state :view)))})

(def rpc-funcs
  "RPC functions"
  @{:refresh (fn [&] :ok)
    :stop close-peers-stop})

(def initial-state
  "Initial state"
  ((=> (=>symbiont-initial-state :admin-sentry)
       (>put :routes routes)
       (>put :static false)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))


(defn main
  ```
  Main entry into sentry.
  Initializes manager, transacts HTTP and awaits it.
  ```
  [&]
  (-> initial-state
      (make-manager on-error)
      (:transact PrepareView HTTP RPC)
      :await)
  (os/exit 0))
