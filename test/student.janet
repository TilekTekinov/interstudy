(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/tree)
(import /machines/student)

(start-suite :docs)
(assert-docs "/machines/student")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(ev/go tree/main)
(ev/sleep 0.01) # Settle the server

(init-test :student)
(:save test-store @{} :registrations)
(:flush test-store)
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
       "<label for='fullname'>" "Fullname" "<input name='fullname' id='fullname' type='text'" "required"
       "<label for='email'>" "Email" "<input name='email' id='email' type='email'" "required"
       "<label for='birth-date'>" "Date of birth" "<input name='birth-date' id='birth-date'" "required"
       "<label for='home-university'>" "Home university" "<input name='home-university' id='home-university'" "required"
       "<label for='faculty'>" "Faculty" "<select name='faculty' id='faculty'" "required" "<option"
       "<label for='study-programme'>" "Study programme" "<select name='study-programme' id='study-programme'" "required" "<option"
       "<button>Register</button>")
      resp)
    "Registration page"))

(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/registration-req"))]
  (assert (success? resp) "Save registration succ")
  (assert ((success-has? "<h1>Registered") resp) "Save registration content"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body "asdfasdc=asfasf")]
  (assert (success? resp) "Reject registration succ")
  (assert ((success-has? "Registration failed") resp) "Reject registration content"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/registration-req"))]
  (assert (success? resp) "Reject email registration succ")
  (assert ((success-has? "Registration failed") resp) "Reject email registration content"))
(end-suite)

(os/exit 0)
