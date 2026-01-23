(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /machines/tree)

(start-suite :docs)
(assert-docs "/machines/tree")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(ev/go tree/main)
(ev/sleep 0.01) # Settle the server

(start-suite :rpc)
(let [c (client ;(server/host-port rpc-url) "test" psk)]
  (assert c)
  (each coll tree/collections
    (assert (c coll))
    (let [ss (coll c)]
      (assert (present? ss))))
  (assert (c :active-courses))
  (assert (empty? (:active-courses c)))
  (assert (c :active-semester))
  (assert (nil? (:active-semester c)))
  (assert (c :set-active-semester))
  (assert (= :ok (:set-active-semester c "Winter")))
  (assert (= "Winter" (:active-semester c)))
  (assert-not (empty? (:active-courses c))
              "Active after active semester")
  (assert ((>find-from-start (??? {:code (?eq "EAE56E")}))
            (:active-courses c)) "Active course")
  (assert (c :save-course))
  (assert (= :ok (:save-course c "EAE56E" {:active false})))
  (assert-not ((>find-from-start (??? {:code (?eq "EAE56E")}))
                (:active-courses c)) "Deactivated course"))

(end-suite)
(os/exit 0)
