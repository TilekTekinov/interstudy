(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test /environment /schema spork/http gp/net/rpc)
(import /symbionts/tree)

(start-suite :docs)
(assert-docs "/symbionts/tree")
(end-suite)

(init-test :tree)
(load-dump "test/data.jdn")
(ev/go tree/main)
(ev/sleep 0.01) # Settle the server

(start-suite :rpc)
(let [tree (client ;(server/host-port rpc-url) "test" psk)]
  (assert tree)
  (each coll [;tree/collections/leafs]
    (assert (tree coll))
    (let [ss (coll tree)]
      (assert (present? ss) (string "Present collection " coll))))
  (each coll [;tree/collections/fruits]
    (assert (tree coll))
    (let [ss (coll tree)]
      (assert (empty? ss) (string "Empty collection " coll))))
  (assert (tree :active-courses))
  (assert (empty? (:active-courses tree)) "Empty active courses")
  (assert (tree :active-semester))
  (assert (nil? (:active-semester tree)))
  (assert (tree :set-active-semester))
  (assert (= :ok (:set-active-semester tree "Winter")))
  (assert (= "Winter" (:active-semester tree)))
  (assert-not (empty? (:active-courses tree))
              "Active after active semester")
  (assert ((>find-from-start (??? {:code (?eq "EAE56E")}))
            (:active-courses tree)) "Active course")
  (assert (tree :save-course))
  (assert (= :ok (:save-course tree "EAE56E" {:active false})))
  (assert-not ((>find-from-start (??? {:code (?eq "EAE56E")}))
                (:active-courses tree)) "Deactivated course")
  (assert (= :ok (:set-active-semester tree false)))
  (assert-not (:active-semester tree) "No active semester")
  (assert (empty? (:registrations tree)) "Empty registrations")
  (assert (= :ok (:save-registration tree (hash "josef@pospisil.work")
                                     @{:birth-date "1973-01-10"
                                       :email "josef@pospisil.work"
                                       :faculty "FE"
                                       :fullname "Josef Posp\xC3\xAD\xC5\xA1il"
                                       :home-university "Oxford"
                                       :study-programme "Erasmus+ (EU)"
                                       :timestamp (os/time)})) "Save registration")
  (assert-not (empty? (:registrations tree)) "Present registrations")
  (assert (empty? (:enrollments tree)) "Empty enrollments")
  (assert (= :ok (:save-enrollment tree (hash "josef@pospisil.work")
                                   @{:course-1 "EAE56E"
                                     :course-2 "EIE67E"
                                     :course-3 "ENE49E"
                                     :course-4 "EEEI2E"
                                     :course-5 "EEEB5E"
                                     :course-6 "EEEF4E"
                                     :timestamp 1768995243})) "Save registration")
  (assert-not (empty? (:enrollments tree)) "Present enrollments"))


(end-suite)
(os/exit 0)
