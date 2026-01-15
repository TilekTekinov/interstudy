(use spork/test)
(import /environment)


(start-suite :docs)
(assert-docs "/environment")
(end-suite)
