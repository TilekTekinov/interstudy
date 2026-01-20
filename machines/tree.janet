(use /environment /schema)

(def rpc-funcs
  "RPC functions for the tree"
  @{:subjects (fn [rpc] [])})

(def config
  "Configuration"
  ((=> (=>machine-initial-state :tree)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(defn main
  ```
	Main entry into interstudy.

	Initializes manager, transacts HTTP and awaits it.
  ```
  [_]
  (-> config
      (make-manager on-error)
      (:transact PrepareStore)
      (:transact HTTP RPC)
      :await)
  (os/exit 0))
