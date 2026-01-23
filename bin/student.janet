(use /environment)
(import spork/path)

(watch-spawn project-files-peg ["janet" "-d" (path/join "machines" "student.janet")])
