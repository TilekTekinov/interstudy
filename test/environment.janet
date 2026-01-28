(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test)
(use /schema)
(use /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)

(start-suite :utils)
(assert (deep= ((=>symbiont-initial-state :admin) compile-config)
               @{:cookie-host "localhost"
                 :debug true
                 :host "localhost"
                 :http "localhost:8778"
                 :log false
                 :name "admin"
                 :neighbors [:student]
                 :student "http://localhost:8777"
                 :peers [:tree]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :public "public"
                 :release-path "/var/code/insterstudy"
                 :rpc "localhost:5446"
                 :static true
                 :thicket "interstudy"
                 :tree "localhost:5444"})
        "symbiont config navigation")
(assert (deep= ((update-rpc @{}) "localhost:4444") @{:url "localhost:4444" :functions @{}}))
(assert ((??? {length (?eq 10)})
          (fixtures 10
                    ["John" "Ringo" "George" "Joseph"]
                    ["Smith" "Doe" "Grave" "Norman"])))
(end-suite)
