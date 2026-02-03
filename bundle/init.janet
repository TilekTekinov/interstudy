(use spork/declare-cc spork/path spork/sh /environment /schema)

(declare-project :name "interstudy")

(declare-executable
  :name "tree"
  :entry "tree.janet")

(declare-executable
  :name "student"
  :entry "student.janet")

(declare-executable
  :name "admin"
  :entry "admin.janet")

(defn check
  [&]
  (def start (os/clock))
  (var pass-count 0)
  (var total-count 0)
  (def failing @[])
  (print "\e[2J\e[H\e[30;103m---------------------- Running Tests ------------------------\e[0m")
  (each dir (sorted (os/dir "test"))
    (def path (string "test/" dir))
    (when (string/has-suffix? ".janet" path)
      (print "----------------- In file " path " -----------------")
      (def pass
        (zero? (os/execute [(dyn *executable* "janet") "--" path] :p)))
      (++ total-count)
      (if pass
        (++ pass-count)
        (array/push failing path))
      (print)))
  (if (= pass-count total-count)
    (print "\e[30;102m--------------------- All tests passed in " (precise-time (- (os/clock) start)) "! ---------------------\e[0m")
    (do
      (print "\e[97;101m--------------------- Some tests failed! ---------------------\e[0m\n")
      (printf "%d of %d passed. Failing scripts:" pass-count total-count)
      (each f failing
        (print "  \e[97;101m" f "\e[0m"))
      (os/exit 1))))
