(use gp/data/schema gp/data/navigation)

(def?! entity
  table?
  {keys (>check all keyword?)
   values (>check all (>check-all some string? epoch? number? array? keyword?))
   :timestamp epoch?})

(def?! registration
  entity?
  {:email present-string?
   :faculty present-string?
   :fullname present-string?
   :home-university present-string?})

(def?! enrollment
  entity?
  @{:course-1 present-string?
    :course-2 present-string?
    :course-3 present-string?
    :course-4 present-string?
    :course-5 present-string?
    :course-6 present-string?}
  (fn [e] (= (length (values e))
             (length (distinct (values e))))))

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
  {:image (?optional present-string?)})

(def?! named-config
  {:name present-string?})

(def?! tree-config
  dictionary?
  persisted-config?)

(def?! avatar-config
  dictionary?
  persisted-config?
  {:timeout (?optional number?)})

(def?! symbiont-config
  dictionary?
  (>check-all some avatar-config? tree-config?))

(def?! symbionts-config
  dictionary?
  {keys (>?? all keyword)
   values (>?? all symbiont-config?)})

(def?! mycelium-node
  dictionary?
  {:rpc url?
   :peers (?optional (??? tuple? (>?? all keyword?)))
   :key (?optional present-string?)})

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
   :symbionts symbionts-config?
   :mycelium mycelium-config?
   :membranes membranes-config?})

(def compile-config
  "Compile time configuration"
  (let [c (parse (slurp (os/getenv "CONF" "conf.jdn")))]
    (or (config? c)
        (do
          (eprint "Config does not conform to its schema. Exiting!")
          (eprintf "%Q" (config! c))
          (os/exit 1)))))
