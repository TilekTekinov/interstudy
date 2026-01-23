(os/setenv "CONF" "test/conf.test.jdn")

(use gp/utils)

(defn main
  "Runs tests on whole project, or optionaly `file`"
  [_ &opt filename]
  (def script
    (if filename
      ["janet" filename]
      [(script "janet-pm") "test"]))
  (watch-spawn '(+
                  (* (+ "machines" "bundle" "test" "schema" "environment" "dev")
                     (thru ".janet") -1)
                  (* "templates" (thru ".temple") -1))
               script true))
