(use /environment /schema)

(defn /index
  "Index page."
  [req]
  (http/page app {:content "Hello World!"}))

(def routes
  "Application routes"
  @{"/" (http/html-get /index)})

(def config
  "Configuration"
  (merge ((=> (=>machine-config :student) tuple
              (>merge @{:routes routes})
              (>update :rpc (update-rpc @{}))) compile-config)))

(defn main
  ```
	Main entry into interstudy.

	Initializes manager, transacts HTTP and awaits it.
  ```
  [_]
  (-> config
      (make-manager on-error)
      (:transact HTTP RPC)
      :await)
  (os/exit 0))
