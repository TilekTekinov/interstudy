(os/setenv "CONF" "test/conf.test.jdn")
(use spork/test)
(use /schema)
(use /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)

(start-suite :utils)
(assert (deep= ((=>symbiont-initial-state :tree) compile-config)
               @{:build-path "./test"
                 :data-path "./test/data"
                 :debug true
                 :dry true
                 :env "dev"
                 :host "test.localhost"
                 :image "test/data/tree"
                 :log false
                 :name :tree
                 :peers []
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :release-path "./test/_release"
                 :rpc "localhost:5444"
                 :thicket "interstudy"})
        "tree config navigation")
(assert (deep= ((=>symbiont-initial-state :student) compile-config)
               @{:address "http://test.localhost:8777"
                 :build-path "./test"
                 :cookie-host "localhost"
                 :data-path "./test/data" :debug true
                 :debug true
                 :dry true
                 :env "dev"
                 :host "test.localhost"
                 :http "localhost:8777"
                 :log false
                 :name :student
                 :peers [:tree]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :public "test/public"
                 :release-path "./test/_release"
                 :rpc "localhost:5445"
                 :static true
                 :thicket "interstudy"
                 :tree "localhost:5444"})
        "student config navigation")
(assert (deep= ((=>symbiont-initial-state :admin) compile-config)
               @{:address "http://test.localhost:8778"
                 :build-path "./test"
                 :cookie-host "localhost"
                 :data-path "./test/data"
                 :debug true
                 :dry true
                 :env "dev"
                 :guarded-by :admin-sentry
                 :host "test.localhost"
                 :http "localhost:8778"
                 :log false
                 :name :admin
                 :neighbors [:student]
                 :peers [:tree]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :public "test/public"
                 :release-path "./test/_release"
                 :rpc "localhost:5446"
                 :static true
                 :student "http://test.localhost:8777"
                 :thicket "interstudy"
                 :tree "localhost:5444"})
        "admin config navigation")
(assert (deep= ((=>symbiont-initial-state :admin-sentry) compile-config)
               @{:address "http://test.localhost:8778"
                 :build-path "./test"
                 :cookie-host "localhost"
                 :data-path "./test/data"
                 :debug true
                 :dry true
                 :env "dev"
                 :guards :admin
                 :host "test.localhost"
                 :http "localhost:8778"
                 :key "\xF6`\xF6\xC1.\x89\xFF\x8C\x95\xB0P\x973\xE4)o\x11\xBEH\x1DW\xF8Dp5\xD6\xC6\x8F\xBE\x03\x9F\xA8"
                 :log false
                 :name :admin-sentry
                 :neighbors [:student]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :peers [:tree]
                 :public "test/public"
                 :release-path "./test/_release"
                 :rpc "localhost:5446"
                 :secret "\x01\xE2D\xC9\xB2\x03\e\xC7\x18\x86\xB9_\x92\xE2Y\e\xDEa;\xEB\xB7R;\x05\x8D\x95\x8D\xCB\xEC\xA7\n\x18\xF8L\xEF\t\xE2\x18M\x9E*\x9E\xBB\xE7v+\xC8f04\xD0\xD4\x8Cc\x04\xE1\f\xBF\xCC\xC5,\x1Cn\xF1\xD1\xBD\xAA\x0F]\x9B+\xF2h>\xE2\xB9\x99\xC0#h\xBD;\xCF\xEA\t]\xBE\xB75\x96\x98\xBF\xA5L7zj\xAF\xC5\x82\xDC3\x99\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                 :static true
                 :thicket "interstudy"})
        "admin-sentry config navigation")
(assert (deep= ((=>symbiont-initial-state :viewer) compile-config)
               @{:address "http://test.localhost:8779"
                 :build-path "./test"
                 :cookie-host "localhost"
                 :data-path "./test/data"
                 :debug true
                 :dry true
                 :env "dev"
                 :guarded-by :viewer-sentry
                 :host "test.localhost"
                 :http "localhost:8779"
                 :log false
                 :name :viewer
                 :neighbors [:student]
                 :peers [:tree]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :public "test/public"
                 :release-path "./test/_release"
                 :rpc "localhost:5447"
                 :static true
                 :student "http://test.localhost:8777"
                 :thicket "interstudy"
                 :tree "localhost:5444"})
        "viewer config navigation")
(assert (deep= ((=>symbiont-initial-state :viewer-sentry) compile-config)
               @{:address "http://test.localhost:8779"
                 :build-path "./test"
                 :cookie-host "localhost"
                 :data-path "./test/data"
                 :debug true
                 :dry true
                 :env "dev"
                 :guards :viewer
                 :host "test.localhost"
                 :http "localhost:8779"
                 :key "\xF6`\xF6\xC1.\x89\xFF\x8C\x95\xB0P\x973\xE4)o\x11\xBEH\x1DW\xF8Dp5\xD6\xC6\x8F\xBE\x03\x9F\xA8"
                 :log false
                 :name :viewer-sentry
                 :neighbors [:student]
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :peers [:tree]
                 :public "test/public"
                 :release-path "./test/_release"
                 :rpc "localhost:5447"
                 :secret "\x01\xE2D\xC9\xB2\x03\e\xC7\x18\x86\xB9_\x92\xE2Y\e\xDEa;\xEB\xB7R;\x05\x8D\x95\x8D\xCB\xEC\xA7\n\x18\xF8L\xEF\t\xE2\x18M\x9E*\x9E\xBB\xE7v+\xC8f04\xD0\xD4\x8Cc\x04\xE1\f\xBF\xCC\xC5,\x1Cn\xF1\xD1\xBD\xAA\x0F]\x9B+\xF2h>\xE2\xB9\x99\xC0#h\xBD;\xCF\xEA\t]\xBE\xB75\x96\x98\xBF\xA5L7zj\xAF\xC5\x82\xDC3\x99\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                 :static true
                 :thicket "interstudy"})
        "viewer-sentry config navigation")
(assert (deep= ((=>symbiont-initial-state :demiurge) compile-config)
               @{:autostart [:tree :student :admin-sentry :viewer-sentry]
                 :build-path "./test"
                 :builder false
                 :data-path "./test/data"
                 :debug true
                 :dry true
                 :env "dev"
                 :host "test.localhost"
                 :log false
                 :name :demiurge
                 :peers []
                 :psk "[\xCE0h\xD6>\xC7.\xE6\xF6\xA3\xE0z\x98\xFB\xDB\xE64l@\xCB\xBBr\xD8\xBA\xF6\xB9\xA9\x8B\xE6H\xF1"
                 :release-path "./test/_release"
                 :rpc "test.localhost:5443"
                 :thicket "interstudy"})
        "demiurge config navigation")
(assert (deep= ((update-rpc @{}) "localhost:4444") @{:url "localhost:4444" :functions @{}}))
(assert ((??? {length (?eq 10)})
          (fixtures 10
                    ["John" "Ringo" "George" "Joseph"]
                    ["Smith" "Doe" "Grave" "Norman"])))
(end-suite)
