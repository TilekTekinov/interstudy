(os/setenv "CONF" "test/conf.test.jdn") # move to bin/test?

(use spork/test spork/misc spork/http
     gp/data/store gp/data/schema gp/data/navigation
     /environment /schema)
(import /sentries/admin)

(start-suite :docs)
(assert-docs "/sentries/admin")
(end-suite)

(init-test :admin-sentry)
(ev/go admin/main)
(ev/sleep 0.01) # Settle the server
(start-suite :new-auth)
(assert (success? (request "GET" (url "/"))) "auth form succ")
(assert ((success-has? "<h1" "Authentication" "<form" "<label" "secret" "<input" "password" "<button")
          (request "GET" (url "/")))
          "auth form succ content")
(assert ((success-has? "<h2" "Authentication failed")
          (request "POST" (url "/")
                   :headers {"Content-Type" "application/x-www-form-urlencoded"}
                   :body "secret=sentry"))
          "auth failed succ content")
(assert ((success-has? "<h1" "Authentication" "<form" "<label" "secret" "<input" "password" "<button")
          (request "GET" (url "/new/whatever")))
          "catch all GET")
(assert ((success-has? "<h1" "Authentication" "<form" "<label" "secret" "<input" "password" "<button")
          (request "POST" (url "/new/whatever")))
          "catch all POST")
(assert ((redirect? "/")
          (request "POST" (url "/")
                   :headers {"Content-Type" "application/x-www-form-urlencoded"}
                   :body "secret=testist")))
(end-suite)

