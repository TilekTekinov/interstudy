(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /tree)
(import /admin)

(start-suite :docs)
(assert-docs "/admin")
(end-suite)

(init-test :tree)
(load-dump "test/seed.jdn")
(def tree-server (os/spawn ["janet" "tree.janet"] :p))
(ev/sleep 0.1) # Settle the tree
(def tree-client
  (client ;(server/host-port rpc-url) :test psk))
(:save-registration tree-client (hash "josef@pospisil.work")
                    @{:email "josef@pospisil.work"
                      :faculty "FE"
                      :fullname "Josef Pospíšil"
                      :home-university "Oxford"
                      :timestamp (os/time)})
(:save-enrollment tree-client (hash "josef@pospisil.work")
                  @{:courses
                    @["EAE56E" "ETEA1E" "AHA29E"]
                    :credits 15
                    :timestamp 1768995243})

(init-test :admin)
(ev/go (fn [] (admin/main "admin" "abcd")))
(ev/sleep 0.05) # Settle the server

(start-suite :http)
(let [resp (request "GET" (url "/"))]
  (assert (success? resp))
  (assert
    ((success-has? `<h1>Interstudy - Admin` `Collections`
                   `/semesters`
                   `/registrations`
                   `/courses`) resp)))
(end-suite)

(start-suite :sse)
(let [resp (request "GET" (url "/semesters")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="semesters` `<details` `<summary>Semesters`
                   `<table` `name` `active` `action`
                   `<a data-on:click` `/semesters/activate/` `Activate`)
      resp)))
(let [resp (request "GET" (url "/semesters/activate/Winter"))]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="semesters` `<details open` `<summary>Semesters`
                   `Winter` `x`
                   `Summer` `<a data-on:click` `/semesters/activate/` `Activate`)
      resp)) "Activate response")
(let [resp (request "GET" (url "/semesters")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp))
  (assert ((success-has? `<div id="semesters` `<details` `<summary>Semesters`
                         `Winter` `x`
                         `Summer` `<a data-on:click` `@get(` `/semesters/activate/` `Activate`)
            resp) "After activate"))
(let [resp (request "GET" (url "/courses")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Courses succ")
  (assert
    ((success-has? `<div id="courses` `<details`
                   `<summary>` `Courses`
                   `Search`
                   `Only active` `<input` `data-on:change` `/courses/filter/`
                   `Only enrolled` `<input` `data-on:change` `/courses/filter/`
                   `Winter semester` `<input` `data-on:change` `/courses/filter/`
                   `Summer semester` `<input` `data-on:change` `/courses/filter/`
                   `<table` `code` `name` `credits` `active` `enrolled` `action`
                   `<a data-on:click="@get(&#39;/courses/enrolled` `1&nbsp;enrolled`
                   `<a data-on:click="@get(&#39;/courses/edit/` `Edit`) resp)
    "Courses succ content"))
(let [resp (request "POST" (url "/courses/search")
                    :headers {"Cookie" "session=abcd" "Content-Type" "application/json"}
                    :body `{"search":"e"}`)]
  (assert (success? resp) "Search succ")
  (assert
    ((success-has? `<div id="courses` `<details` `<summary>` `Courses`
                   `Search`
                   `<table` `code` `name` `credits` `active` `enrolled` `action`)
      resp) "Search succ content"))
(let [resp (request "GET" (url "/courses/enrolled/EAE56E")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Course enrolled succ")
  (assert ((success-has? `<tr id="EAE56E-enrolled`) resp) "Course enrolled succ content"))
(let [resp (request "GET" (url `/courses/filter/?datastar=%7B%22search%22%3A%22%22%2C%22active%22%3Atrue%2C%22semester%22%3A%22%22%7D`)
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Active filter succ")
  (assert ((success-has? `<details open` `<td class="active">x</td>`) resp) "Some active")
  (assert ((success-has-not? `<td class="active"></td>`) resp) "No not active"))
(let [resp (request "GET" (url "/courses/filter/?datastar=%7B%22search%22%3A%22%22%2C%22active%22%3Afalse%2C%22semester%22%3A%22Winter%22%7D")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Filter winter succ")
  (assert ((success-has? `<td>Winter</td>`) resp) "Some Winter")
  (assert ((success-has-not? `<td>Summer</td>`) resp) "No Summer"))
(let [resp (request "GET" (url "/courses/edit/EAE56E")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp))
  (assert ((success-has?
             `data-signals=`
             `<input data-bind="name"`
             `<select data-bind="credits"`
             `<select data-bind="semester"`
             `<input data-bind="active"`
             `<button` `Save`) resp)))
(let [resp (request "POST" (url "/courses/save/EAE56E")
                    :body `{"active": false}`
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Save course")
  (assert ((success-has? `<tr` "EAE56E") resp) "Save subject content"))
(let [resp (request "GET" (url "/semesters/deactivate")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="semesters` `<details open` `<summary>Semesters`
                   `Winter` `<a data-on:click` `/semesters/activate/` `Activate`
                   `Summer` `<a data-on:click` `/semesters/activate/` `Activate`)
      resp)))
(let [resp (request "GET" (url "/registrations")
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Registrations succ")
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `Filter:` `Only enrolled` `<table` `Fullname` `Email` `Registered` `Enrollment`
                   `Josef Pospíšil` `josef@pospisil.work` `3 for 15 credits`)
      resp) "Registration succ content"))
(let [resp (request "POST" (url "/registrations/search")
                    :headers {"Content-Type" "application/json"
                              "Cookie" "session=abcd"}
                    :body `{"search":"j"}`)]
  (assert (success? resp) "Registrations search succ")
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Registered` `Enrollment`
                   `Josef Pospíšil` `josef@pospisil.work` `3 for 15 credits`)
      resp) "Registrations search succ content"))
(let [resp (request "GET" (url `/registrations/filter/?datastar=%7B%22search%22%3A%22%22%2C%22enrolled%22%3Atrue%2C%22active%22%3Afalse%2C%22semester%22%3A%22%22%7D`)
                    :headers {"Cookie" "session=abcd"})]
  (assert (success? resp) "Enrolled filter succ")
  (assert ((success-has? `<details open` `Josef`) resp) "No active"))
(let [resp (request "GET" (url `/logout`)
                    :headers {"Cookie" "session=abcd"})]
  (assert ((redirect? "/") resp) "Logout filter succ"))
(end-suite)

(start-suite :rpc)
(let [admin (client ;(server/host-port rpc-url) "test" psk)]
  (assert (= :pong (:ping admin)))
  (assert (= :ok (:refresh admin :active-semester))))

(end-suite)

(os/exit 0)
