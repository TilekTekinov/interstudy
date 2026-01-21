(use gp/data/schema gp/data/navigation)

(def?! entity
  table?
  {keys (>check all keyword?)
   values (>check all (>check-all some string? epoch? number? array? keyword?))
   :timestamp epoch?})

(def?! registration
  entity?
  {:birth-date present-string?
   :email present-string?
   :faculty present-string?
   :fullname present-string?
   :home-university present-string?
   :study-programme present-string?})

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

(def?! url
  present-string?
  (?matches-peg '(* (to ":") ":" (some :d) -1)))

(def?! deploy-config
  dictionary?
  {:host present-string?
   :release-path present-string?
   :debug boolean?
   :log boolean?})

(def?! persisted-config
  {:image present-string?})

(def?! named-config
  {:name present-string?})

(def?! tree-config
  dictionary?
  persisted-config?)

(def?! avatar-config
  dictionary?
  persisted-config?
  {:timeout number?})

(def?! machine-config
  dictionary?
  (>check-all some avatar-config? tree-config?))

(def?! machines-config
  dictionary?
  {keys (>?? all keyword)
   values (>?? all machine-config?)})

(def?! mycelium-node
  dictionary?
  {:rpc url?
   :key present-string?})

(def?! mycelium-nodes-config
  dictionary?
  {keys (>?? all keyword)
   values (>?? all mycelium-node?)})

(def?! mycelium-config
  dictionary?
  {:psk present-string?
   :nodes mycelium-nodes-config?})

(def?! membrane-node
  dictionary?
  {:http url?
   :cookie-host present-string?
   :static boolean?
   :public (?optional present-string?)})

(def?! membrane-nodes-config
  dictionary?
  {keys (>?? all keyword)
   values (>?? all membrane-node?)})

(def?! membranes-config
  dictionary?
  {:nodes membrane-nodes-config?})

(def?! config
  dictionary?
  {:name present-string?
   :deploy deploy-config?
   :machines machines-config?
   :mycelium mycelium-config?
   :membranes membranes-config?})

(def compile-config
  "Compile time configuration"
  (parse (slurp (os/getenv "CONF" "conf.jdn"))))

# (let [c (parse (slurp (os/getenv "CONF" "conf.jdn")))]
#   (or (config? c)
#       (do
#         (eprint "Config does not conform to its schema. Exiting!")
#         (eprintf "%Q" (config! c))
#         (os/exit 1))))

