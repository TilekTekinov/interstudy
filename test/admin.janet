(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /symbionts/tree)
(import /symbionts/admin)

(start-suite :docs)
(assert-docs "/symbionts/admin")
(end-suite)

(init-test :tree)
(load-dump "test/seed.jdn")
(def tree-server (os/spawn ["janet" "symbionts/tree.janet"] :p))
(ev/sleep 0.05) # Settle the server
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
(ev/go admin/main)
(ev/sleep 0.05) # Settle the server

(start-suite :http)
(let [resp (request "GET" (url "/"))]
  (assert (success? resp))
  (assert
    ((success-has? `<h1>Interstudy - Admin` `Collections`
                   `/semesters` `Semesters`
                   `/registrations` `Registrations`
                   `/courses` `Courses`) resp)))
(end-suite)

(start-suite :sse)
(let [resp (request "GET" (url "/semesters"))]
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
(let [resp (request "GET" (url "/semesters"))]
  (assert (success? resp))
  (assert ((success-has? `<div id="semesters` `<details` `<summary>Semesters`
                         `Winter` `x`
                         `Summer` `<a data-on:click` `@get(` `/semesters/activate/` `Activate`)
            resp) "After activate"))
(let [resp (request "GET" (url "/courses"))]
  (assert (success? resp) "Courses succ")
  (assert
    ((success-has? `<div id="courses` `<details`
                   `<summary>` `Courses`
                   `Only active` `<input` `data-on:change` `/courses/filter/` 
                   `Only enrolled` `<input` `data-on:change` `/courses/filter/` 
                   `Winter semester` `<input` `data-on:change` `/courses/filter/` 
                   `Summer semester` `<input` `data-on:change` `/courses/filter/` 
                   `<table` `code` `name` `credits` `active` `enrolled` `action`
                   `<td>1&nbsp;enrolled</td>` `<a data-on:click` `/courses/edit/` `Edit`) resp)
                  "Courses succ content"))
(let [resp (request "GET" (url `/courses/filter/?datastar=%7B%22search%22%3A%22%22%2C%22active%22%3Atrue%2C%22semester%22%3A%22%22%7D`))]
  (assert (success? resp) "Active filter succ")
  (assert ((success-has? `<details open` `<td class="active">x</td>`) resp) "Some active")
  (assert ((success-has-not? `<td class="active"></td>`) resp) "No not active"))
(let [resp (request "GET" (url "/courses/filter/?datastar=%7B%22search%22%3A%22%22%2C%22active%22%3Afalse%2C%22semester%22%3A%22Winter%22%7D"))]
  (assert (success? resp) "Filter winter succ")
  (assert ((success-has? `<td>Winter</td>`) resp) "Some Winter")
  (assert ((success-has-not? `<td>Summer</td>`) resp) "No Summer"))
(let [resp (request "GET" (url "/courses/edit/EAE56E"))]
  (assert (success? resp))
  (assert ((success-has?
             `data-signals=`
             `<input data-bind="name"`
             `<select data-bind="credits"`
             `<select data-bind="semester"`
             `<input data-bind="active"`
             `<button` `Save`) resp)))
(let [resp (request "POST" (url "/courses/EAE56E")
                    :body `{"active": false}`)]
  (assert (success? resp) "Save course")
  (assert ((success-has? `<tr` "EAE56E") resp) "Save subject content"))
(let [resp (request "GET" (url "/semesters/deactivate"))]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="semesters` `<details open` `<summary>Semesters`
                   `Winter` `<a data-on:click` `/semesters/activate/` `Activate`
                   `Summer` `<a data-on:click` `/semesters/activate/` `Activate`)
      resp)))
(let [resp (request "GET" (url "/registrations"))]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Registered` `Enrollment`
                   `Josef Pospíšil` `josef@pospisil.work` `3 for 15 credits`)
      resp)))
(let [resp (request "POST" (url "/registrations/search")
                    :headers {"Content-Type" "application/json"}
                    :body `{"search":"j"}`)]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Registered` `Enrollment`
                   `Josef Pospíšil` `josef@pospisil.work` `3 for 15 credits`)
      resp)))
(end-suite)

(start-suite :rpc)
(let [admin (client ;(server/host-port rpc-url) "test" psk)]
  (assert (= :pong (:ping admin)))
  (assert (= :ok (:refresh admin :active-semester))))

(end-suite)

(os/exit 0)
