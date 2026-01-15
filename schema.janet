(use gp/data/schema gp/data/navigation)

(def?! entity
  table?
  {keys (>check all keyword?)
   values (>check all (>check-all some string? epoch? number? array? keyword?))
   :timestamp epoch?})

(def?! session-payload
  table?
  {:logged epoch?
   :active epoch?})

(def?! session
  tuple?
  {first present-string?
   last session-payload?})

(def?! store
  table?
  {:session session?})

(def?! deploy-config
  dictionary?
  {:host present-string?
   :release-path present-string?
   :debug boolean?
   :log boolean?})

(def?! tree-config
  dictionary?
  {:image bytes?
   :key present-string?
   :rpc (?optional present-string?)})

(def?! avatar-config
  dictionary?
  {:image bytes?
   :sentry boolean?
   :http present-string?
   :cookie-host present-string?
   :static boolean?
   :public present-string?
   :key present-string?
   :rpc (?optional present-string?)})

(def?! machine-config
  dictionary?
  (>check-all some avatar-config? tree-config?))

(def?! machines-config
  dictionary?
  {values (>?? all machine-config?)})

(def?! node
  dictionary?
  {:rpc present-string?})

(def?! nodes-config
  dictionary?
  {keys (>?? all keyword)
   values (>?? all node?)})

(def?! mycelium-config
  dictionary?
  {:psk present-string?
   :nodes nodes-config?})

(def?! config
  dictionary?
  {:deploy deploy-config?
   :machines machines-config?
   :mycelium mycelium-config?})

(def compile-config
  "Compile time configuration"
  (let [c (parse (slurp (os/getenv "CONF" "conf.jdn")))]
    (or (config? c)
        (do
          (eprint "Config does not conform to its schema. Exiting!")
          (eprintf "%Q" (config! c))
          (os/exit 1)))))
