we do not proceed with installation if some files in the .install
are missing.

  $ dune build @install
  $ rm -rf _build/install/default/bin
  $ dune install
  The following files which are listed in _build/default/foo.install cannot be installed because they do not exist:
  - install/default/bin/foo
  [1]
