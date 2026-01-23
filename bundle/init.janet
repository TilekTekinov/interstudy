(use spork/declare-cc spork/path spork/sh /environment /schema)

(declare-project :name "interstudy")

(declare-executable
  :name "tree"
  :entry "symbionts/tree.janet")

(declare-executable
  :name "student"
  :entry "symbionts/student.janet")

(declare-executable
  :name "admin"
  :entry "symbionts/admin.janet")


(defn check
  [&]
  (var pass-count 0)
  (var total-count 0)
  (def failing @[])
  (each dir (sorted (os/dir "test"))
    (def path (string "test/" dir))
    (when (string/has-suffix? ".janet" path)
      (print "In file " path)
      (def pass (zero? (os/execute [(dyn *executable* "janet") "--" path] :p)))
      (++ total-count)
      (unless pass (array/push failing path))
      (when pass (++ pass-count))))
  (if (= pass-count total-count)
    (print "--------------------- All tests passed! ---------------------")
    (do
      (printf "%d of %d passed." pass-count total-count)
      (print "failing scripts:")
      (each f failing
        (print "  " f))
      (os/exit 1))))
