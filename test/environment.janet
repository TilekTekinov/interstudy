(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test)
(use /schema)
(import /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)

(start-suite :utils)
(assert (deep= ((environment/=>machine-initial-state :student) compile-config)
               @{:debug true
                 :host "localhost"
                 :image "test/student"
                 :key "{dU\xFE\x8D`\x84Q%Q\xF7\x0E\xFA\xF8\x17\x83\x03\x9A7&,\xE9\x8C9\xF0;5\xE3\x93|\x13\x9A"
                 :log false
                 :thicket "interstudy"
                 :name "student"
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :release-path "/var/code/insterstudy"
                 :rpc "localhost:4445"
                 :timeout 300})
        "machine config navigation")
(assert (deep= ((environment/update-rpc @{}) "localhost:4444") @{:url "localhost:4444" :functions @{}}))
(end-suite)
