(use ./environment /schema)

(def initial-state
  "Initial state"
  ((=>sentry-initial-state :viewer-sentry) compile-config))

(defn main
  ```
  Main entry into sentry.
  Initializes manager, transacts HTTP and awaits it.
  ```
  [&]
  (sentry-main))
