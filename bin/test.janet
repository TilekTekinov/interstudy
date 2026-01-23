(os/setenv "CONF" "test/conf.test.jdn")

(use /environment)

(defn main
  "Runs tests on whole project, or optionaly `filename`"
  [_ &opt filename]
  (def script
    (if filename
      ["janet" filename]
      [(script "janet-pm") "test"]))
  (watch-spawn project-files-peg script true))
