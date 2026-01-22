(use gp/utils)
(import spork/path)

(watch-spawn '(+ (* (thru "temple") -1)
                 (* (thru "janet") -1)) ["janet" "-d" (path/join "machines" "admin.janet")])
