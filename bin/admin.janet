(use /environment)
(import spork/path)

(watch-spawn project-files-peg ["janet" "-e" "(ev/sleep 0.1)" "-d" "admin/init.janet"])
