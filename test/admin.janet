(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/tree)
(import /machines/admin)

(start-suite :docs)
(assert-docs "/machines/admin")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(def tree-server (os/spawn ["janet" "machines/tree.janet"] :p))
(ev/sleep 0.05) # Settle the server

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
(let [resp (request "GET" (url "/courses"))]
  (assert (success? resp))
  (assert
    ((success-has? "<div id='courses'" "<details open" "<summary>Courses"
                   "<table" "code" "name" "credits" "active" "action"
                   "<a data-on:click" "/courses/edit/" "Edit") resp)))
(let [resp (request "GET" (url "/courses/edit/EAE56E"))]
  (assert (success? resp))
  (assert ((success-has? "course-form" "<label for='active'"
                         "<input type='checkbox'" "id='active"
                         "<button" "Save") resp)))
(let [resp (request "POST" (url "/courses/EAE56E")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body "")]
  (assert (success? resp) "Save course")
  (assert ((success-has? "<h2>Saving") resp) "Save subject content"))
(let [resp (request "GET" (url "/semesters/deactivate"))]
  (assert (success? resp))
  (assert
    ((success-has? "<div id='semesters'" "<details open" "<summary>Semesters"
                   "Winter" "<a data-on:click" "/semesters/activate/" "Activate"
                   "Summer" "<a data-on:click" "/semesters/activate/" "Activate")
      resp)))
(end-suite)

(os/exit 0)
