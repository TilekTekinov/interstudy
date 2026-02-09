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
  (var demiurge (os/spawn ["janet" "-d" "demiurge.janet"] :p))
  (ev/sleep 0.1)
  (var client (rpc/client ;(server/host-port (conf :rpc))
                          :client (conf :psk)))
  (:run-peers client)
  (filewatch/add fw "./" :last-write :recursive) # TODO check linux
  (filewatch/listen fw)
  (forever (def e (ev/take ch))
    (when-let [[fnm] (peg/match mp (e :file-name))]
      (eprinf "----------- File %s modified, restarting " fnm)
      (if (peg/match '(* "demiurge.janet" -1) fnm)
        (do
          (eprint "Demiurge")
          (:stop client)
          (os/proc-wait demiurge)
          (set demiurge (os/spawn ["janet" "-d" "demiurge.janet"] :p))
          (ev/sleep 0.1)
          (set client (rpc/client ;(server/host-port (conf :rpc))
                                  :client (conf :psk)))
          (:run-peers client))
        (do
          (eprint "Peers")
          (:stop-peers client)
          (ev/sleep 0.1)
          (:run-peers client)
          (ev/drain ch))))))
