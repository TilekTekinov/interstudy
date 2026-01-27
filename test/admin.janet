(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /symbionts/tree)
(import /symbionts/admin)

(start-suite :docs)
(assert-docs "/symbionts/admin")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(def tree-server (os/spawn ["janet" "symbionts/tree.janet"] :p))
(ev/sleep 0.05) # Settle the server

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
(let [resp (request "GET" (url "/registrations"))]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Action`)
      resp)))
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
  (assert (success? resp))
  (assert
    ((success-has? `<div id="courses` `<details`
                   `<summary>` `Courses`
                   `<a data-on:click=` `/courses/filter/active` `Only active`
                   `<a data-on:click=` `/courses/filter/semester/Winter` `Winter semester`
                   `<a data-on:click=` `/courses/filter/semester/Summer` `Summer semester`
                   `<table` `code` `name` `credits` `active` `action`
                   `<a data-on:click` `/courses/edit/` `Edit`) resp)))
(let [resp (request "GET" (url "/courses/filter/active"))]
  (assert (success? resp))
  (assert ((success-has? `<details open` `<td>x</td>`) resp) "Some active")
  (assert ((success-has-not? `<td></td>`) resp) "No not active"))
(let [resp (request "GET" (url "/courses/filter/semester/Winter"))]
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
(let [resp (request "POST" (url "/registrations/search")
                    :headers {"Content-Type" "application/json"}
                    :body `{"search":"a"}`)]
  (assert (success? resp))
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Action`)
      resp)))
(end-suite)

(start-suite :rpc)
(let [admin (client ;(server/host-port rpc-url) "test" psk)]
  (assert (= :pong (:ping admin)))
  (assert (= :ok (:refresh admin :active-semester))))

(end-suite)

(os/exit 0)
