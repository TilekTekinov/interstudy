(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test)
(use /schema)
(import /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)

(start-suite :utils)
(assert (deep= ((environment/=>symbiont-initial-state :student true) compile-config)
               @{:cookie-host "localhost"
                 :debug true
                 :host "localhost"
                 :http "localhost:8777"
                 :image "test/student"
                 :key "{dU\xFE\x8D`\x84Q%Q\xF7\x0E\xFA\xF8\x17\x83\x03\x9A7&,\xE9\x8C9\xF0;5\xE3\x93|\x13\x9A"
                 :log false
                 :name "student"
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :public "public"
                 :release-path "/var/code/insterstudy"
                 :rpc "localhost:5445"
                 :static true
                 :thicket "interstudy"
                 :timeout 300
                 :tree "localhost:5444"})
        "symbiont config navigation")
(assert (deep= ((environment/update-rpc @{}) "localhost:4444") @{:url "localhost:4444" :functions @{}}))
(end-suite)
