(os/setenv "CONF" "test/conf.test.jdn")

(use spork/test gp/data/schema /environment)
(import /schema)

(start-suite :utils)
(assert?! schema/url "localhost:4444")
(end-suite)

(start-suite :config)
(assert?! schema/tree-config ((=> :symbionts :tree) schema/compile-config))
(assert?! schema/avatar-config ((=> :symbionts :student) schema/compile-config))
(assert?! schema/symbionts-config (schema/compile-config :symbionts))
(assert?! schema/mycelium-config (schema/compile-config :mycelium))
(assert?! schema/membranes-config (schema/compile-config :membranes))
(assert (schema/config? schema/compile-config))
(end-suite)

(start-suite :entities)
(assert?! schema/registration
          @{:email "josef@pospisil.work"
            :faculty "FE"
            :fullname "Josef Posp\xC3\xAD\xC5\xA1il"
            :home-university "Oxford"
            :timestamp (os/time)})
(assert?! schema/enrollment
          @{:courses
            @["EAE56E"
              "EIE67E"
              "ENE49E"
              "EEEI2E"
              "EEEB5E"
              "EEEF4E"]
            :credits 30
            :timestamp 1768995243})
(assert-not?! schema/enrollment
              @{:courses
                @["EAE56E"
                  "EAE56E"
                  "ENE49E"
                  "EEEI2E"
                  "EEEB5E"
                  "EEEF4E"]
                :timestamp 1768995243})
(assert-not?! schema/enrollment
              @{:courses
                ["EAE56E"
                 ""
                 "ENE49E"
                 "EEEI2E"
                 "EEEB5E"
                 "EEEF4E"]
                :timestamp 1768995243})
(end-suite)
