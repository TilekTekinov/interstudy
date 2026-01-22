(use gp/utils)
(import spork/path)

(watch-spawn '(+ (* (thru "temple") -1)
                 (* (thru "janet") -1)) ["janet" "-e" "(ev/sleep 0.1)" "-d" (path/join "machines" "admin.janet")])
