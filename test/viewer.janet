(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /tree)
(import /admin/viewer)

(start-suite :docs)
(assert-docs "/admin/viewer")
(end-suite)

(init-test :tree)
(load-dump "test/seed.jdn")
(def tree-server (os/spawn ["janet" "tree.janet"] :p))
(ev/sleep 0.1) # Settle the server
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

(init-test :viewer)
(ev/go viewer/main)
(ev/sleep 0.05) # Settle the server
(start-suite :http)
(let [resp (request "GET" (url "/"))]
  (assert (success? resp))
  (assert
    ((success-has? `<h1>Interstudy - Viewer` `/registrations`) resp)))
(let [resp (request "GET" (url "/registrations"))]
  (assert (success? resp) "Registrations succ")
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Registered` `Enrollment`
                   `Josef Pospíšil` `josef@pospisil.work` `3 for 15 credits`)
      resp) "Registration succ content"))
(let [resp (request "POST" (url "/registrations/search")
                    :headers {"Content-Type" "application/json"}
                    :body `{"search":"j"}`)]
  (assert (success? resp) "Registrations search succ")
  (assert
    ((success-has? `<div id="registrations` `<details` `<summary>` `Registrations`
                   `Search` `<table` `Fullname` `Email` `Registered` `Enrollment`
                   `Josef Pospíšil` `josef@pospisil.work` `3 for 15 credits`)
      resp) "Registrations search succ content"))
(let [resp (request "GET" (url `/registrations/filter/?datastar=%7B%22search%22%3A%22%22%2C%22enrolled%22%3Atrue%2C%22active%22%3Afalse%2C%22semester%22%3A%22%22%7D`))]
  (assert (success? resp) "Enrolled filter succ")
  (assert ((success-has? `<details open` `Josef`) resp) "No active"))
(end-suite)
(os/exit 0)
