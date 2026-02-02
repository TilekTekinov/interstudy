(use /environment /schema spork/sh-dsl)

(defn main
  "Script that releases and runs the new version on the server"
  [&]
  (let [{:host host :build-path bp :release-path rp}
        (get compile-config :deploy)
        rbp (path/posix/join "/" ;(butlast (path/parts bp)))
        sbp (path/posix/join rpb spork)
        url ($<_ git remote get-url origin)]
    (os/execute
      (tracev (ssh-cmds host [:mkdir :-p rbp] [:mkdir :-p rp]
                        [:git :clone "--depth=1" url bp]
                        [:git :clone "--depth=1" "https://github.com/janet-lang/spork" sbp]
                        [:janet "--install" sbp]
                        ["/usr/local/lib/janet/bin/janet-pm" :full-env :prod]
                        ["/usr/local/lib/janet/bin/janet-pm" :load-lockfile "https://git.sr.ht/~pepe/gp"]
                        [:janet-pm :quickbin "demiurge.janet" "demiurge"]
                        [:mv "demiurge" rp] [:cd rp])) :p)
    (os/execute (ssh-cmds host [:nohup "demiurge" ">" "/dev/null" "2>&1" "&"]))))
