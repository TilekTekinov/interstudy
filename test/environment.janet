(use spork/test)
(import /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)

(start-suite :utils)
(assert (deep= ((environment/update-rpc @{}) "localhost:4444") @{:url "localhost:4444" :functions @{}}))
(end-suite)
