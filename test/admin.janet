(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/tree)
(import /machines/admin)

(start-suite :docs)
(assert-docs "/machines/admin")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(ev/go tree/main)
(ev/sleep 0.01) # Settle the server
(init-test :admin)

(ev/go admin/main)
(ev/sleep 0.05) # Settle the server

(start-suite :http)
(let [resp (request "GET" (url "/"))]
  (assert (success? resp))
  (assert
    ((success-has? "<h1>Interstudy - Admin" "Collections" "Courses") resp)))
(end-suite)
(start-suite :sse)
(let [resp (request "GET" (url "/courses"))]
  (assert (success? resp))
  (assert
    ((success-has? "<div id='courses'" "<details open" "<summary>Courses"
                   "<table" "code" "name" "credits" "active" "action"
                   "<a data-on:click" "/courses/edit/" "Edit")
      resp)))
(end-suite)

(os/exit 0)
