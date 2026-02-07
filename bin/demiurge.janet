(import spork/path)
(use /environment /schema)

(def conf
  "Navigation to initial state in config"
  ((=>symbiont-initial-state :demiurge) compile-config))

(defn main
  "Demiurge client main entry"
  [_]
  (def ch (ev/chan 9))
  (def fw (filewatch/new ch))
  (def mp (peg/compile ~{:matcher ,project-files-peg :main (<- :matcher)}))
  (os/spawn ["janet" "-d" "demiurge.janet"] :p)
  (ev/sleep 0.1)
  (def client (rpc/client ;(server/host-port (conf :rpc))
                          :client (conf :psk)))
  (:run-all client)
  (filewatch/add fw "./" :last-write :recursive) # TODO check linux
  (filewatch/listen fw)
  (forever (def e (ev/take ch))
    (when-let [[fnm] (peg/match mp (e :file-name))]
      (eprintf "----------- File %s modified, restarting" fnm)
      (:stop-all client)
      (ev/sleep 0.1)
      (:run-all client)
      (ev/drain ch))))
