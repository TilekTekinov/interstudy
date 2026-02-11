(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /demiurge)

(start-suite :docs)
(assert-docs "/demiurge")
(end-suite)

(init-test :demiurge)
(ev/go demiurge/main)
(ev/sleep 0.01) # Settle the server

(start-suite :rpc)
(let [demiurge (client ;(server/host-port rpc-url) "test" psk)]
  (assert demiurge)
  (assert (= :pong (:ping demiurge)))
  (ev/sleep 0.01)
  (assert ((??? (?long 3)
                {0 (?eq :idle)
                 1 present-string?
                 2 nil?})
            (:state demiurge)))
  (assert ((??? {0 ok?
                 1 epoch?
                 2 nil?})
            (:release demiurge)))
  (assert (ok? (:run-peers demiurge)))
  (assert ((??? {0 (?eq :running)
                 1 epoch?
                 2 array?})
            (:state demiurge)))
  (assert (ok? (:stop-peers demiurge)))
  (assert (ok? (:update-config demiurge compile-config)))
  (assert (ok? (:stop demiurge))))
(end-suite)
(os/exit 0)
