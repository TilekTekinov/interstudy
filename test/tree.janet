(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/tree)

(start-suite :docs)
(assert-docs "/machines/tree")
(end-suite)

(init-test :tree)
(ev/go tree/main)
(ev/sleep 0.01) # Settle the server

(start-suite :rpc)
(let [c (client ;(server/host-port rpc-url) "test" psk)]
  (assert c)
  (assert (:subjects c)))

(end-suite)
(os/exit 0)
