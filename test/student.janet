(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/tree)
(import /machines/student)

(start-suite :docs)
(assert-docs "/machines/student")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(:save test-store "Winter" :active-semester)
(:flush test-store)
(ev/go tree/main)
(ev/sleep 0.01) # Settle the server

(init-test :student)
(:save test-store @{} :registrations)
(:save test-store @{} :enrollments)
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
  (assert ((success-has? "<h2>Registered" "<a href='/enroll/23e365ca71557c832c39f7ba12d72d0c") resp) "Save registration content"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body "asdfasdc=asfasf")]
  (assert (success? resp) "Reject registration succ")
  (assert ((success-has? "Registration failed") resp) "Reject registration content"))
(let [resp (request "POST" (url "/")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/registration-req"))]
  (assert (success? resp) "Reject email registration succ")
  (assert ((success-has? "Registration failed" "value='Josef") resp) "Reject email registration content"))
(let [resp (request "GET" (url "/enroll/23e365ca71557c832c39f7ba12d72d0c"))]
  (assert (success? resp))
  (assert
    ((success-has? "Enrollment" "Student: Josef Pospíšil &lt;josef@pospisil.work&gt;" "Please choose"
                   "<form" "post" "/enroll/23e365ca71557c832c39f7ba12d72d0c"
                   "<label for='course-1'>" "Course&nbsp;1" "<select name='course-1' id='course-1'" "required" "<option"
                   "<label for='course-2'>" "Course&nbsp;2" "<select name='course-2' id='course-2'" "required" "<option"
                   "<label for='course-3'>" "Course&nbsp;3" "<select name='course-3' id='course-3'" "required" "<option"
                   "<label for='course-4'>" "Course&nbsp;4" "<select name='course-4' id='course-4'" "required" "<option"
                   "<label for='course-5'>" "Course&nbsp;5" "<select name='course-5' id='course-5'" "required" "<option"
                   "<label for='course-6'>" "Course&nbsp;6" "<select name='course-6' id='course-6'" "required" "<option"
                   "<button>Enroll")
      resp)))
(let [resp (request "POST" (url "/enroll/23e365ca71557c832c39f7ba12d72d0c")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/enrollment-req"))]
  (assert (success? resp) "Save enrollment succ")
  (assert ((success-has? "<h2>Enrolled") resp) "Save enrollment content"))
(let [resp (request "POST" (url "/enroll/23e365ca71557c832c39f7ba12d72d0c")
                    :headers {"Content-Type" "application/x-www-form-urlencoded"}
                    :body (slurp "test/dup-enrollment-req"))]
  (assert (success? resp) "Reject enrollment succ")
  (assert ((success-has? "Not enrolled. All courses must be unique.") resp) "Reject enrollment content"))
(end-suite)

(os/exit 0)
