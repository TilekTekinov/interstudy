(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /demiurge)

(start-suite :docs)
(assert-docs "/demiurge")
(end-suite)

(init-test :demiurge)
(ev/go demiurge/main)
(ev/sleep 0.01) # Settle the server

(def?! sha string? (?long 40))
(def?! ok (?eq :ok))

(start-suite :rpc)
(let [demiurge (client ;(server/host-port rpc-url) "test" psk)]
  (assert demiurge)
  (assert (= :pong (:ping demiurge)))
  (assert ((??? {0 (?eq :idle)
                 1 nil?})
            (:state demiurge)))
  (assert ((??? {0 ok?
                 1 epoch?})
            (:release demiurge)))
  (assert ((??? {0 (?eq :busy)
                 1 epoch?})
            (:state demiurge)))
  (assert ((??? {0 (?eq :busy)
                 1 epoch?})
            (:release demiurge)))
  (assert (ok? (:run-all demiurge)))
  (assert (ok? (:stop-all demiurge)))
  (assert (ok? (:run-all demiurge)))
  (assert (ok? (:stop demiurge))))
(end-suite)
(os/exit 0)
