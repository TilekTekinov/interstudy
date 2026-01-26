(use /environment /schema)

(def- jp "/usr/local/lib/janet/bin/janet-pm")

(defn main
  "Script that releases and runs the new version on the server"
  [&]
  (let [{:host host :release-path rp}
        ((=> :deploy (>select-keys :host :release-path)) compile-config)]
    (print "Pull the latest version and build")
    (os/execute
      (ssh-cmds host [:cd rp] [:git :pull] [:doas jp :deps]
                [jp :clean] [jp :build]) :p)
    (print "Kill servers")
    (os/execute (ssh-cmds host [:pkill "student"] [:pkill "admin"] [:pkill "tree"]) :p)
    (print "Run tree server")
    (os/execute
      (ssh-cmds host [:cd rp] ["nohup" "_build/release/tree" ">" "/dev/null" "2>&1" "&"]) :p)
    (os/sleep 0.5)
    (print "Run student server")
    (os/execute
      (ssh-cmds host [:cd rp] ["nohup" "_build/release/student" ">" "/dev/null" "2>&1" "&"]) :p)
    (print "Run admin server")
    (os/execute
      (ssh-cmds host [:cd rp] ["nohup" "_build/release/admin" ">" "/dev/null" "2>&1" "&"]) :p)))
