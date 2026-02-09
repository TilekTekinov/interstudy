# TODO test the RPC fail over
(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /tree)
(import /student)

(start-suite :docs)
(assert-docs "/student")
(end-suite)

(init-test :tree)
(load-dump "test/seed.jdn")
(:save test-store "Winter" :active-semester)
(:flush test-store)
(os/spawn ["janet" "tree.janet"] :p)
(ev/sleep 0.1) # Settle the server

(init-test :student)
(ev/go student/main)
(ev/sleep 0.05) # Settle the server

(start-suite :http)
(let [resp (request "GET" (url "/"))]
  (assert (success? resp))
  (assert
    ((success-has?
       "<h1>Interstudy - Registration"
       "<h2>All fields are required"
       "<form" "post" "/"
       `<label for="fullname">` `Fullname` `<input` `name="fullname"` `id="fullname"` `type="text"` `required`
       `<label for="email">` `Email` `<input` `name="email"` `id="email"` `type="email"` `required`
       `<label for="home-university">` `Home university` `<input` `name="home-university"` `id="home-university"` `required`
       `<label for="faculty">` `Faculty` `<select` `name="faculty"` `id="faculty"` `required` `<option`
       "<button>Register</button>")
      resp)
    "Registration page"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/registration-req"))]
  (assert (success? resp) "Save registration succ")
  (assert ((success-has? "<h2>Registered" "<a href='/enroll/d73e5fabb537b904d535047420894bc1") resp)
          "Save registration content"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body "asdfasdc=asfasf")]
  (assert (success? resp) "Reject registration succ")
  (assert ((success-has? "Registration failed") resp) "Reject registration content"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/registration-req"))]
  (assert (success? resp) "Reject email registration succ")
  (assert ((success-has? "Registration failed" `value="Josef`) resp) "Reject email registration content"))
(let [resp (request "GET" (url "/enroll/d73e5fabb537b904d535047420894bc1"))]
  (assert (success? resp))
  (assert
    ((success-has? "Enrollment" "Student: Josef Pospíšil &lt;josef@pospisil.work&gt;"
                   "<form" `<label for="course-0">` `Course` `<select` `name="course-0"` `<option` `EAE56E (5)`)
      resp) "Enrollment form allowed content")
  (assert
    ((success-has-not? "<label for='course-1'>" "Course&nbsp;2" "<select name='course-2' id='course-2'" "required" "<option" "EAE56E"
                       "<button>Enroll")
      resp) "Enrollment form disallowed content"))
(let [resp (request "GET" (url "/enroll/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))]
  (assert (not-found? resp) "Not found GET"))
(let [resp (request "POST" (url "/enroll/d73e5fabb537b904d535047420894bc1")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (json/encode {:course-0 "EAE56E"}))]
  (assert (success? resp) "Save enrollment succ"))
(comment
  (let [resp (request "POST" (url "/enroll/d73e5fabb537b904d535047420894bc1")
                      :headers {"Content-Type" "application/x-www-form-urlencoded"}
                      :body (json/encode {:course-0 "EAE56E" :course-1 "EAE56E"}))]
    (assert (success? resp) "Reject enrollment succ")
    (assert ((success-has? "Not enrolled. All courses must be unique.") resp) "Reject enrollment content")))
(let [resp (request "POST" (url "/enroll/ffffffffffffffffffffffffffffffff")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (json/encode {:course-0 "EAE56E"}))]
  (assert (not-found? resp) "Not found POST"))
(end-suite)

(start-suite :rpc)
(let [student (client ;(server/host-port rpc-url) "test" psk)]
  (assert (= :pong (:ping student)))
  (assert (= :ok (:refresh student :active-semester))))

(end-suite)

(os/exit 0)
