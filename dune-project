(lang dune 3.0)

(name spendo)

(source
 (github tcosmo/spendo))

(generate_opam_files true)

(package
 (name spendo)
 (synopsis "A simple CLI utility for tracking daily expenses")
 (description
  "Spendo is a command-line tool for tracking daily expenses with optional categorization.")
 (depends
  (ocaml
   (>= 4.14.0))
  (dune
   (>= 3.0))
  (unix :build)
  (yojson :build)
  (cmdliner :build)
  (alcotest :dev))
 (allow_empty))
