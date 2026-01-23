(import spork/path)
(use /environment)

(watch-spawn project-files-peg ["janet" "-d" (path/join "symbionts" "tree.janet")])
