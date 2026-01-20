(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/student)

(start-suite :docs)
(assert-docs "/machines/student")
(end-suite)


# (init-test :student)
# (ev/go student/main)
# (ev/sleep 0.01) # Settle the server

# (start-suite :http)
# (assert (request "GET" (url "/")))
# (end-suite)

# (start-suite :rpc)
# (client ;(server/host-port rpc-url) "test" psk)
# (end-suite)
# (os/exit 0)
