(use /environment /schema spork/sh spork/sh-dsl)

(defn main
  "Script that bootstraps demiurge on the server"
  [&]
  (let [{:host host :build-path bp :data-path dp :release-path rp}
        (get compile-config :deploy)
        rbp (path/posix/join "/" ;(butlast (path/parts bp)))
        sbp (path/posix/join rbp "spork")
        url ($<_ git remote get-url origin)
        conf (os/getenv "CONF" "conf.jdn")]
    (eprint "------------ Ensure paths")
    (exec
      ;(ssh-cmds host
                 [:rm "-rf" bp] [:rm "-rf" sbp]
                 [:mkdir :-p rbp] [:mkdir :-p rp] [:mkdir :-p dp]))
    (eprint "------------ Ensure repositories")
    (exec
      ;(ssh-cmds host
                 [:git :clone "--depth=1" url bp]
                 [:git :clone "--depth=1"
                  "https://github.com/janet-lang/spork" sbp]))
    (eprint "------------ Ensure environment")
    (exec
      ;(ssh-cmds host
                 [:cd bp]
                 ["/usr/local/lib/janet/bin/janet-pm" :full-env :prod]
                 [". ./prod/bin/activate"]
                 [:janet "--install" sbp]
                 [:janet-pm :install "jhydro"]
                 [:janet-pm :install "https://git.sr.ht/~pepe/gp"]))
    (eprint "------------ Upload configuration")
    (exec "scp" conf (string host ":" bp "/conf.jdn"))
    (eprint "------------ Quickbin demiurge")
    (exec ;(ssh-cmds host
                     [:cd bp] [". ./prod/bin/activate"]
                     [:janet-pm :quickbin "demiurge.janet" "demiurge"]
                     [:mv "demiurge" rp]
                     [:janet "bin/seed-tree.janet" "t"]))
    (eprint "------------ Run demiurge")
    (exec ;(ssh-cmds host [:nohup (path/posix/join rp "/demiurge")
                           ">" "/dev/null" "2>&1" "&"]))))
