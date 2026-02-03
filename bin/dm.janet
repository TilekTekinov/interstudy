(use /environment /schema)

(def conf
  "Navigation to initial state in config"
  ((=>symbiont-initial-state :demiurge) compile-config))

(defn main
  "Demiurge client main entry"
  [_ cmd]
  (def client (rpc/client ;(server/host-port (conf :rpc))
                          :client (conf :psk)))
  (pp (cmd client)))
