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
    ((success-has? "<h1>Interstudy - Admin" "Collections"
                   "/semesters" "Semesters"
                   "/courses" "Courses") resp)))
(end-suite)
(start-suite :sse)
(let [resp (request "GET" (url "/semesters"))]
  (assert (success? resp))
  (assert
    ((success-has? "<div id='semesters'" "<details open" "<summary>Semesters"
                   "<table" "name" "active" "action"
                   "<a data-on:click" "/semesters/activate/" "Activate")
      resp)))
(let [resp (request "GET" (url "/semesters"))]
  (assert (success? resp))
  (assert
    ((success-has? "<div id='semesters'" "<details open" "<summary>Semesters"
                   "<table" "name" "active" "action"
                   "<a data-on:click" "/semesters/activate/" "Activate")
      resp)))
(let [resp (request "GET" (url "/semesters/activate/Winter"))]
  (assert (success? resp))
  (assert
    ((success-has? "<div id='semesters'" "<details open" "<summary>Semesters"
                   "Winter" "x"
                   "Summer" "<a data-on:click" "/semesters/activate/" "Activate")
      resp)))
(let [resp (request "GET" (url "/semesters"))]
  (assert (success? resp))
  (assert ((success-has? "<div id='semesters'" "<details open" "<summary>Semesters"
                         "Winter" "x"
                         "Summer" "<a data-on:click" "/semesters/activate/" "Activate")
            resp) "After activate"))
(end-suite)

(os/exit 0)
