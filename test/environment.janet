(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test)
(use /schema)
(use /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)

(start-suite :utils)
(assert (deep= ((=>symbiont-initial-state :admin) compile-config)
               @{:address "http://test.localhost:8778"
                 :build-path "./"
                 :cookie-host "localhost"
                 :data-path "./"
                 :debug true
                 :dry true
                 :host "test.localhost"
                 :http "localhost:8778"
                 :log false
                 :name "admin"
                 :neighbors [:student]
                 :peers [:tree]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :public "public"
                 :release-path "./_release"
                 :rpc "localhost:5446"
                 :static true
                 :student "http://test.localhost:8777"
                 :thicket "interstudy"
                 :tree "localhost:5444"})
        "admin config navigation")
(assert (deep= ((=>symbiont-initial-state :demiurge) compile-config)
               @{:build-path "./"
                 :data-path "./"
                 :debug true
                 :dry true
                 :host "test.localhost"
                 :log false
                 :name "demiurge"
                 :peers []
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :release-path "./_release"
                 :rpc "localhost:5442"
                 :thicket "interstudy"})
        "demiurge config navigation")
(assert (deep= ((update-rpc @{}) "localhost:4444") @{:url "localhost:4444" :functions @{}}))
(assert ((??? {length (?eq 10)})
          (fixtures 10
                    ["John" "Ringo" "George" "Joseph"]
                    ["Smith" "Doe" "Grave" "Norman"])))
(end-suite)
