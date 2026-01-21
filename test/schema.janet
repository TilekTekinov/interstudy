(os/setenv "CONF" "test/conf.test.jdn")

(use spork/test gp/data/schema /environment)
(import /schema)

(start-suite :utils)
(assert?! schema/url "localhost:4444")
(end-suite)

(start-suite :config)
(assert?! schema/tree-config ((=> :machines :tree) schema/compile-config))
(assert?! schema/avatar-config ((=> :machines :student) schema/compile-config))
(assert?! schema/machines-config (schema/compile-config :machines))
(assert?! schema/mycelium-config (schema/compile-config :mycelium))
(assert?! schema/membranes-config (schema/compile-config :membranes))
(assert (schema/config? schema/compile-config))
(end-suite)

(start-suite :entities)
(assert?! schema/registration
          @{:birth-date "1973-01-10"
            :email "josef@pospisil.work"
            :faculty "FE"
            :fullname "Josef Posp\xC3\xAD\xC5\xA1il"
            :home-university "Oxford"
            :study-programme "Erasmus+ (EU)"
            :timestamp (os/time)})
(end-suite)
