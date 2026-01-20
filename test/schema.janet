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
