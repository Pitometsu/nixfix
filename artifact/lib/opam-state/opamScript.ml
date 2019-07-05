(* THIS FILE IS AUTOMATICALLY GENERATED, EDIT ../Makefile INSTEAD *)
let bwrap =
"#!/usr/bin/env bash\n\nset -ue\n\nif ! command -v bwrap >/dev/null; then\n    echo \"The 'bwrap' command was not found. Install 'bubblewrap' on your system, or\" >&2\n    echo \"disable sandboxing in ${OPAMROOT:-~/.opam}/config at your own risk.\" >&2\n    echo \"See https://github.com/projectatomic/bubblewrap for bwrap details.\" >&2\n    echo \"For 'bwrap' use in opam, see the FAQ:\" >&2\n    echo \"  https://opam.ocaml.org/doc/2.0/FAQ.html#Why-does-opam-require-bwrap\" >&2\n    exit 10\nfi\n\nARGS=(--unshare-net --new-session)\nARGS=(\"${ARGS[@]}\" --proc /proc --dev /dev)\nARGS=(\"${ARGS[@]}\" --bind \"${TMPDIR:-/tmp}\" /tmp)\nARGS=(\"${ARGS[@]}\" --setenv TMPDIR /tmp --setenv TMP /tmp --setenv TEMPDIR /tmp --setenv TEMP /tmp)\nARGS=(\"${ARGS[@]}\" --tmpfs /run)\n\nadd_mount() {\n    case \"$1\" in\n        ro) B=\"--ro-bind\";;\n        rw) B=\"--bind\";;\n        sym) B=\"--symlink\";;\n    esac\n    ARGS=(\"${ARGS[@]}\" \"$B\" \"$2\" \"$3\")\n}\n\nadd_mounts() {\n    local flag=\"$1\"; shift\n    for dir in \"$@\"; do\n      if [ -d \"$dir\" ]; then\n        add_mount \"$flag\" \"$dir\" \"$dir\"\n      fi\n    done\n}\n\n# Mounts the standard system paths. Maintains symlinks, to handle cases\n# like `/bin` -> `usr/bin`, where `/bin/../foo` resolves to `/usr/foo`,\n# not `/foo`. We handle symlinks here but not in `add_mounts` because\n# system paths are pretty much guaranteed not to accidentally escape into\n# off-limits directories.\nadd_sys_mounts() {\n    for dir in \"$@\"; do\n        if [ -L \"$dir\" ]; then\n            local src=$(readlink -f \"$dir\")\n            add_mount sym \"$src\" \"$dir\"\n        else\n            add_mounts ro \"$dir\"\n        fi\n    done\n}\n\n# remove some unusual pathes (/nix/stored and /rw/usrlocal )\n# use OPAM_USER_PATH_RO variable to add them\n# the OPAM_USER_PATH_RO format is the same as PATH\n# ie: export OPAM_USER_PATH_RO=/nix/store:/rw/usrlocal\nadd_sys_mounts /usr /bin /lib /lib32 /lib64 /etc /opt /home /var\n\n# C compilers using `ccache` will write to a shared cache directory\n# that remain writeable. ccache seems widespread in some Fedora systems.\nadd_ccache_mount() {\n  if command -v ccache > /dev/null; then\n      CCACHE_DIR=$HOME/.ccache\n      ccache_dir_regex='cache_dir = (.*)$'\n      local IFS=$'\\n'\n      for f in $(ccache --print-config 2>/dev/null); do\n        if [[ $f =~ $ccache_dir_regex ]]; then\n          CCACHE_DIR=${BASH_REMATCH[1]}\n        fi\n      done\n      add_mounts rw $CCACHE_DIR\n  fi\n}\n\n# This case-switch should remain identical between the different sandbox implems\nCOMMAND=\"$1\"; shift\ncase \"$COMMAND\" in\n    build)\n        # mount unusual path in ro\n        if  [ -n \"${OPAM_USER_PATH_RO-}\" ]; then\n           add_mounts ro $(echo ${OPAM_USER_PATH_RO} | sed 's|:| |g')\n        fi\n        add_mounts ro \"$OPAM_SWITCH_PREFIX\"\n        add_mounts rw \"$PWD\"\n        add_ccache_mount\n        ;;\n    install)\n        # mount unusual path in ro\n        if  [ -n \"${OPAM_USER_PATH_RO-}\" ]; then\n           add_mounts ro  $(echo ${OPAM_USER_PATH_RO} | sed 's|:| |g')\n        fi\n        add_mounts rw \"$OPAM_SWITCH_PREFIX\"\n        add_mounts ro \"$OPAM_SWITCH_PREFIX/.opam-switch\"\n        add_mounts rw \"$PWD\"\n        ;;\n    remove)\n        # mount unusual path in ro\n        if  [ -n \"${OPAM_USER_PATH_RO-}\" ]; then\n           add_mounts ro $(echo ${OPAM_USER_PATH_RO} | sed 's|:| |g')\n        fi\n        add_mounts rw \"$OPAM_SWITCH_PREFIX\"\n        add_mounts ro \"$OPAM_SWITCH_PREFIX/.opam-switch\"\n        if [ \"X${PWD#$OPAM_SWITCH_PREFIX}/.opam-switch/\" != \"X${PWD}\" ]; then\n          add_mounts rw \"$PWD\"\n        fi\n        ;;\n    *)\n        echo \"$0: unknown command $COMMAND, must be one of 'build', 'install' or 'remove'\" >&2\n        exit 2\nesac\n\n# Note: we assume $1 can be trusted, see https://github.com/projectatomic/bubblewrap/issues/259\nexec bwrap \"${ARGS[@]}\" \"$@\"\n"

let complete =
"if [ -z \"$BASH_VERSION\" ]; then return 0; fi\n\n_opam_add()\n{\n  IFS=$'\\n' _opam_reply+=(\"$@\")\n}\n\n_opam_add_f()\n{\n  local cmd\n  cmd=$1; shift\n  _opam_add \"$($cmd \"$@\" 2>/dev/null)\"\n}\n\n_opam_flags()\n{\n  opam \"$@\" --help=groff 2>/dev/null | \\\n      sed -n \\\n      -e 's%\\\\-\\|\\\\N'\"'45'\"'%-%g' \\\n      -e 's%, \\\\fB%\\n\\\\fB%g' \\\n      -e '/^\\\\fB-/p' | \\\n      sed -e 's%^\\\\fB\\(-[^\\\\]*\\).*%\\1%'\n}\n\n_opam_commands()\n{\n  opam \"$@\" --help=groff 2>/dev/null | \\\n      sed -n \\\n      -e 's%\\\\-\\|\\\\N'\"'45'\"'%-%g' \\\n      -e '/^\\.SH COMMANDS$/,/^\\.SH/ s%^\\\\fB\\([^,= ]*\\)\\\\fR.*%\\1%p'\n  echo '--help'\n}\n\n_opam_vars()\n{\n  opam config list --safe 2>/dev/null | \\\n      sed -n \\\n      -e '/^PKG:/d' \\\n      -e 's%^\\([^#= ][^ ]*\\).*%\\1%p'\n}\n\n_opam_argtype()\n{\n  local cmd flag\n  cmd=\"$1\"; shift\n  flag=\"$1\"; shift\n  case \"$flag\" in\n      -*)\n          opam \"$cmd\" --help=groff 2>/dev/null | \\\n          sed -n \\\n              -e 's%\\\\-\\|\\\\N'\"'45'\"'%-%g' \\\n              -e 's%.*\\\\fB'\"$flag\"'\\\\fR[= ]\\\\fI\\([^, ]*\\)\\\\fR.*%\\1%p'\n          ;;\n  esac\n}\n\n_opam()\n{\n  local IFS cmd subcmd cur prev compgen_opt\n\n  COMPREPLY=()\n  cmd=${COMP_WORDS[1]}\n  subcmd=${COMP_WORDS[2]}\n  cur=${COMP_WORDS[COMP_CWORD]}\n  prev=${COMP_WORDS[COMP_CWORD-1]}\n  compgen_opt=()\n  _opam_reply=()\n\n  if [ $COMP_CWORD -eq 1 ]; then\n      _opam_add_f opam help topics\n      COMPREPLY=( $(compgen -W \"${_opam_reply[*]}\" -- $cur) )\n      unset _opam_reply\n      return 0\n  fi\n\n  case \"$(_opam_argtype $cmd $prev)\" in\n      LEVEL|JOBS|RANK) _opam_add 1 2 3 4 5 6 7 8 9;;\n      FILE|FILENAME) compgen_opt+=(-o filenames -f);;\n      DIR|ROOT) compgen_opt+=(-o filenames -d);;\n      MAKE|CMD) compgen_opt+=(-c);;\n      KIND) _opam_add http local git darcs hg;;\n      WHEN) _opam_add always never auto;;\n      SWITCH|SWITCHES) _opam_add_f opam switch list --safe -s;;\n      COLUMNS|FIELDS)\n          _opam_add name version package synopsis synopsis-or-target \\\n                    description installed-version pin source-hash \\\n                    opam-file all-installed-versions available-versions \\\n                    all-versions repository installed-files vc-ref depexts;;\n      PACKAGE|PACKAGES|PKG|PATTERN|PATTERNS)\n          _opam_add_f opam list --safe -A -s;;\n      FLAG) _opam_add light-uninstall verbose plugin compiler conf;;\n      REPOS) _opam_add_f opam repository list --safe -s -a;;\n      SHELL) _opam_add bash sh csh zsh fish;;\n      TAGS) ;;\n      CRITERIA) ;;\n      STRING) ;;\n      URL)\n          compgen_opt+=(-o filenames -d)\n          _opam_add \"https://\" \"http://\" \"file://\" \\\n                    \"git://\" \"git+file://\" \"git+ssh://\" \"git+https://\" \\\n                    \"hg+file://\" \"hg+ssh://\" \"hg+https://\" \\\n                    \"darcs+file://\" \"darcs+ssh://\" \"darcs+https://\";;\n      \"\")\n  case \"$cmd\" in\n      install|show|info|inst|ins|in|i|inf|sh)\n          _opam_add_f opam list --safe -a -s\n          if [ $COMP_CWORD -gt 2 ]; then\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      reinstall|remove|uninstall|reinst|remov|uninst|unins)\n          _opam_add_f opam list --safe -i -s\n          if [ $COMP_CWORD -gt 2 ]; then\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      upgrade|upg)\n          _opam_add_f opam list --safe -i -s\n          _opam_add_f _opam_flags \"$cmd\"\n          ;;\n      switch|sw)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\"\n                  _opam_add_f opam switch list --safe -s;;\n              3)\n                  case \"$subcmd\" in\n                      create|install)\n                          _opam_add_f opam switch list-available --safe -s -a;;\n                      set|remove|reinstall)\n                          _opam_add_f opam switch list --safe -s;;\n                      import|export)\n                          compgen_opt+=(-o filenames -f);;\n                      *)\n                          _opam_add_f _opam_flags \"$cmd\"\n                  esac;;\n              *)\n                  _opam_add_f _opam_flags \"$cmd\"\n          esac;;\n      config|conf|c)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\";;\n              3)\n                  case \"$subcmd\" in\n                      var) _opam_add_f _opam_vars;;\n                      exec) compgen_opt+=(-c);;\n                      *) _opam_add_f _opam_flags \"$cmd\"\n                  esac;;\n              *)\n                  _opam_add_f _opam_flags \"$cmd\"\n          esac;;\n      repository|remote|repos|repo)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\";;\n              3)\n                  case \"$subcmd\" in\n                      list)\n                          _opam_add_f _opam_flags \"$cmd\";;\n                      *)\n                          _opam_add_f opam repository list --safe -a -s\n                  esac;;\n              *)\n                  _opam_add_f _opam_flags \"$cmd\"\n                  case \"$subcmd\" in\n                      set-url|add) compgen_opt+=(-o filenames -f);;\n                      set-repos) _opam_add_f opam repository list --safe -a -s;;\n                  esac;;\n          esac;;\n      update|upd)\n          _opam_add_f opam repository list --safe -s\n          _opam_add_f opam pin list --safe -s\n          _opam_add_f _opam_flags \"$cmd\"\n          ;;\n      source|so)\n          if [ $COMP_CWORD -eq 2 ]; then\n              _opam_add_f opam list --safe -A -s\n          else\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      pin)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\";;\n              3)\n                  case \"$subcmd\" in\n                      add)\n                          compgen_opt+=(-o filenames -d)\n                          _opam_add_f opam list --safe -A -s;;\n                      remove|edit)\n                          _opam_add_f opam pin list --safe -s;;\n                      *)\n                          _opam_add_f _opam_flags \"$cmd\"\n                  esac;;\n              *)\n                  case \"$subcmd\" in\n                      add)\n                          compgen_opt+=(-o filenames -d);;\n                      *)\n                          _opam_add_f _opam_flags \"$cmd\"\n                  esac\n          esac;;\n      unpin)\n          if [ $COMP_CWORD -eq 2 ]; then\n              _opam_add_f opam pin list --safe -s\n          else\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      var|v)\n          if [ $COMP_CWORD -eq 2 ]; then _opam_add_f _opam_vars\n          else _opam_add_f _opam_flags \"$cmd\"; fi;;\n      exec|e)\n          if [ $COMP_CWORD -eq 2 ]; then compgen_opt+=(-c)\n          else _opam_add_f _opam_flags \"$cmd\"; fi;;\n      lint|build)\n          if [ $COMP_CWORD -eq 2 ]; then\n              compgen_opt+=(-f -X '!*opam' -o plusdirs)\n          else _opam_add_f _opam_flags \"$cmd\"; fi;;\n      admin)\n          if [ $COMP_CWORD -eq 2 ]; then\n              _opam_add_f _opam_commands \"$cmd\"\n          else _opam_add_f _opam_flags \"$cmd\" \"$subcmd\"; fi;;\n      *)\n          _opam_add_f _opam_commands \"$cmd\"\n          _opam_add_f _opam_flags \"$cmd\"\n  esac;;\n  esac\n\n  COMPREPLY=($(compgen -W \"${_opam_reply[*]}\" \"${compgen_opt[@]}\" -- \"$cur\"))\n  unset _opam_reply\n  return 0\n}\n\ncomplete -F _opam opam\n"

let complete_zsh =
"#compdef opam\n\nif [ -z \"$ZSH_VERSION\" ]; then return 0; fi\n\n_opam_add()\n{\n  IFS=$'\\n' _opam_reply+=(\"$@\")\n}\n\n_opam_add_f()\n{\n  local cmd\n  cmd=$1; shift\n  _opam_add \"$($cmd \"$@\" 2>/dev/null)\"\n}\n\n_opam_flags()\n{\n  opam \"$@\" --help=groff 2>/dev/null | \\\n      sed -n \\\n      -e 's%\\\\-\\|\\\\N'\"'45'\"'%-%g' \\\n      -e 's%, \\\\fB%\\n\\\\fB%g' \\\n      -e '/^\\\\fB-/p' | \\\n      sed -e 's%^\\\\fB\\(-[^\\\\]*\\).*%\\1%'\n}\n\n_opam_commands()\n{\n  opam \"$@\" --help=groff 2>/dev/null | \\\n      sed -n \\\n      -e 's%\\\\-\\|\\\\N'\"'45'\"'%-%g' \\\n      -e '/^\\.SH COMMANDS$/,/^\\.SH/ s%^\\\\fB\\([^,= ]*\\)\\\\fR.*%\\1%p'\n  echo '--help'\n}\n\n_opam_vars()\n{\n  opam config list --safe 2>/dev/null | \\\n      sed -n \\\n      -e '/^PKG:/d' \\\n      -e 's%^\\([^#= ][^ ]*\\).*%\\1%p'\n}\n\n_opam_argtype()\n{\n  local cmd flag\n  cmd=\"$1\"; shift\n  flag=\"$1\"; shift\n  case \"$flag\" in\n      -*)\n          opam \"$cmd\" --help=groff 2>/dev/null | \\\n          sed -n \\\n              -e 's%\\\\-\\|\\\\N'\"'45'\"'%-%g' \\\n              -e 's%.*\\\\fB'\"$flag\"'\\\\fR[= ]\\\\fI\\([^, ]*\\)\\\\fR.*%\\1%p'\n          ;;\n  esac\n}\n\n_opam()\n{\n  local IFS cmd subcmd cur prev compgen_opt\n\n  COMPREPLY=()\n  cmd=${COMP_WORDS[1]}\n  subcmd=${COMP_WORDS[2]}\n  cur=${COMP_WORDS[COMP_CWORD]}\n  prev=${COMP_WORDS[COMP_CWORD-1]}\n  compgen_opt=()\n  _opam_reply=()\n\n  if [ $COMP_CWORD -eq 1 ]; then\n      _opam_add_f opam help topics\n      COMPREPLY=( $(compgen -W \"${_opam_reply[*]}\" -- $cur) )\n      unset _opam_reply\n      return 0\n  fi\n\n  case \"$(_opam_argtype $cmd $prev)\" in\n      LEVEL|JOBS|RANK) _opam_add 1 2 3 4 5 6 7 8 9;;\n      FILE|FILENAME) compgen_opt+=(-o filenames -f);;\n      DIR|ROOT) compgen_opt+=(-o filenames -d);;\n      MAKE|CMD) compgen_opt+=(-c);;\n      KIND) _opam_add http local git darcs hg;;\n      WHEN) _opam_add always never auto;;\n      SWITCH|SWITCHES) _opam_add_f opam switch list --safe -s;;\n      COLUMNS|FIELDS)\n          _opam_add name version package synopsis synopsis-or-target \\\n                    description installed-version pin source-hash \\\n                    opam-file all-installed-versions available-versions \\\n                    all-versions repository installed-files vc-ref depexts;;\n      PACKAGE|PACKAGES|PKG|PATTERN|PATTERNS)\n          _opam_add_f opam list --safe -A -s;;\n      FLAG) _opam_add light-uninstall verbose plugin compiler conf;;\n      REPOS) _opam_add_f opam repository list --safe -s -a;;\n      SHELL) _opam_add bash sh csh zsh fish;;\n      TAGS) ;;\n      CRITERIA) ;;\n      STRING) ;;\n      URL)\n          compgen_opt+=(-o filenames -d)\n          _opam_add \"https://\" \"http://\" \"file://\" \\\n                    \"git://\" \"git+file://\" \"git+ssh://\" \"git+https://\" \\\n                    \"hg+file://\" \"hg+ssh://\" \"hg+https://\" \\\n                    \"darcs+file://\" \"darcs+ssh://\" \"darcs+https://\";;\n      \"\")\n  case \"$cmd\" in\n      install|show|info|inst|ins|in|i|inf|sh)\n          _opam_add_f opam list --safe -a -s\n          if [ $COMP_CWORD -gt 2 ]; then\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      reinstall|remove|uninstall|reinst|remov|uninst|unins)\n          _opam_add_f opam list --safe -i -s\n          if [ $COMP_CWORD -gt 2 ]; then\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      upgrade|upg)\n          _opam_add_f opam list --safe -i -s\n          _opam_add_f _opam_flags \"$cmd\"\n          ;;\n      switch|sw)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\"\n                  _opam_add_f opam switch list --safe -s;;\n              3)\n                  case \"$subcmd\" in\n                      create|install)\n                          _opam_add_f opam switch list-available --safe -s -a;;\n                      set|remove|reinstall)\n                          _opam_add_f opam switch list --safe -s;;\n                      import|export)\n                          compgen_opt+=(-o filenames -f);;\n                      *)\n                          _opam_add_f _opam_flags \"$cmd\"\n                  esac;;\n              *)\n                  _opam_add_f _opam_flags \"$cmd\"\n          esac;;\n      config|conf|c)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\";;\n              3)\n                  case \"$subcmd\" in\n                      var) _opam_add_f _opam_vars;;\n                      exec) compgen_opt+=(-c);;\n                      *) _opam_add_f _opam_flags \"$cmd\"\n                  esac;;\n              *)\n                  _opam_add_f _opam_flags \"$cmd\"\n          esac;;\n      repository|remote|repos|repo)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\";;\n              3)\n                  case \"$subcmd\" in\n                      list)\n                          _opam_add_f _opam_flags \"$cmd\";;\n                      *)\n                          _opam_add_f opam repository list --safe -a -s\n                  esac;;\n              *)\n                  _opam_add_f _opam_flags \"$cmd\"\n                  case \"$subcmd\" in\n                      set-url|add) compgen_opt+=(-o filenames -f);;\n                      set-repos) _opam_add_f opam repository list --safe -a -s;;\n                  esac;;\n          esac;;\n      update|upd)\n          _opam_add_f opam repository list --safe -s\n          _opam_add_f opam pin list --safe -s\n          _opam_add_f _opam_flags \"$cmd\"\n          ;;\n      source|so)\n          if [ $COMP_CWORD -eq 2 ]; then\n              _opam_add_f opam list --safe -A -s\n          else\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      pin)\n          case $COMP_CWORD in\n              2)\n                  _opam_add_f _opam_commands \"$cmd\";;\n              3)\n                  case \"$subcmd\" in\n                      add)\n                          compgen_opt+=(-o filenames -d)\n                          _opam_add_f opam list --safe -A -s;;\n                      remove|edit)\n                          _opam_add_f opam pin list --safe -s;;\n                      *)\n                          _opam_add_f _opam_flags \"$cmd\"\n                  esac;;\n              *)\n                  case \"$subcmd\" in\n                      add)\n                          compgen_opt+=(-o filenames -d);;\n                      *)\n                          _opam_add_f _opam_flags \"$cmd\"\n                  esac\n          esac;;\n      unpin)\n          if [ $COMP_CWORD -eq 2 ]; then\n              _opam_add_f opam pin list --safe -s\n          else\n              _opam_add_f _opam_flags \"$cmd\"\n          fi;;\n      var|v)\n          if [ $COMP_CWORD -eq 2 ]; then _opam_add_f _opam_vars\n          else _opam_add_f _opam_flags \"$cmd\"; fi;;\n      exec|e)\n          if [ $COMP_CWORD -eq 2 ]; then compgen_opt+=(-c)\n          else _opam_add_f _opam_flags \"$cmd\"; fi;;\n      lint|build)\n          if [ $COMP_CWORD -eq 2 ]; then\n              compgen_opt+=(-f -X '!*opam' -o plusdirs)\n          else _opam_add_f _opam_flags \"$cmd\"; fi;;\n      admin)\n          if [ $COMP_CWORD -eq 2 ]; then\n              _opam_add_f _opam_commands \"$cmd\"\n          else _opam_add_f _opam_flags \"$cmd\" \"$subcmd\"; fi;;\n      *)\n          _opam_add_f _opam_commands \"$cmd\"\n          _opam_add_f _opam_flags \"$cmd\"\n  esac;;\n  esac\n\n  COMPREPLY=($(compgen -W \"${_opam_reply[*]}\" \"${compgen_opt[@]}\" -- \"$cur\"))\n  unset _opam_reply\n  return 0\n}\n\nautoload bashcompinit\nbashcompinit\ncomplete -F _opam opam\n"

let env_hook_csh =
"alias precmd 'eval `opam env --shell=csh --readonly`'\n"

let env_hook_fish =
"function __opam_env_export_eval --on-event fish_prompt;\n    eval (opam env --shell=fish --readonly ^ /dev/null);\nend\n"

let env_hook =
"_opam_env_hook() {\n local previous_exit_status=$?;\n eval $(opam env --shell=bash --readonly 2> /dev/null);\n return $previous_exit_status;\n};\nif ! [[ \"$PROMPT_COMMAND\" =~ _opam_env_hook ]]; then\n    PROMPT_COMMAND=\"_opam_env_hook;$PROMPT_COMMAND\";\nfi\n"

let env_hook_zsh =
"_opam_env_hook() {\n    eval $(opam env --shell=zsh --readonly 2> /dev/null);\n}\ntypeset -ag precmd_functions;\nif [[ -z ${precmd_functions[(r)_opam_env_hook]} ]]; then\n    precmd_functions+=_opam_env_hook;\nfi\n"

let prompt =
"# This script allows you to see the active opam switch in your prompt. It\n# should be portable across all shells in common use.\n#\n# To enable, change your PS1 to call _opam_ps1 using command substitution. For\n# example, in bash:\n#\n#     PS1=\"$(__opam_ps1 \"(%s)\")\\u@\\h:\\w\\$ \"\n#\n\n__opam_ps1()\n{\n    local exit=$?\n    local printf_format='(%s)'\n\n    case \"$#\" in\n        0|1)    printf_format=\"${1:-$printf_format}\"\n        ;;\n        *)  return $exit\n        ;;\n    esac\n\n    local switch_name=\"$(opam switch show --safe 2>/dev/null)\"\n    if [ -z \"$switch_name\" ]; then\n        return $exit\n    fi\n    printf -- \"$printf_format\" \"$switch_name\"\n    return $exit\n}\n"

let sandbox_exec =
"#!/usr/bin/env bash\nset -ue\n\nPOL='(version 1)(allow default)(deny network*)(deny file-write*)'\nPOL=\"$POL\"'(allow network* (remote unix))'\nPOL=\"$POL\"'(allow file-write* (literal \"/dev/null\") (literal \"/dev/dtracehelper\"))'\n\nadd_mounts() {\n    local DIR=\"$(cd \"$2\" && pwd -P)\"\n    case \"$1\" in\n        ro) POL=\"$POL\"'(deny file-write* (subpath \"'\"$DIR\"'\"))';;\n        rw) POL=\"$POL\"'(allow file-write* (subpath \"'\"$DIR\"'\"))';;\n    esac\n}\n\nif [ -z ${TMPDIR+x} ]; then\n  # If $TMPDIR is not set, some applications use /tmp, so\n  # /tmp must be made readable/writable\n  add_mounts rw /tmp\n  # However, others applications obtain the per-user temporary\n  # directory differently; the latter should be made readable/writable\n  # too and getconf seems to be a robust way to get it\n  if [ -z /usr/bin/getconf ]; then\n    TMP=`getconf DARWIN_USER_TEMP_DIR`\n    add_mounts rw $TMP\n  fi\nelse\n  add_mounts rw $TMPDIR\nfi\n\n# C compilers using `ccache` will write to a shared cache directory\n# that remain writeable. ccache seems widespread in some Fedora systems.\nadd_ccache_mount() {\n  if command -v ccache > /dev/null; then\n      CCACHE_DIR=$HOME/.ccache\n      ccache_dir_regex='cache_dir = (.*)$'\n      local IFS=$'\\n'\n      for f in $(ccache --print-config 2>/dev/null); do\n        if [[ $f =~ $ccache_dir_regex ]]; then\n          CCACHE_DIR=${BASH_REMATCH[1]}\n        fi\n      done\n      add_mounts rw $CCACHE_DIR\n  fi\n}\n\n# This case-switch should remain identical between the different sandbox implems\nCOMMAND=\"$1\"; shift\ncase \"$COMMAND\" in\n    build)\n        add_mounts ro \"$OPAM_SWITCH_PREFIX\"\n        add_mounts rw \"$PWD\"\n        add_ccache_mount\n        ;;\n    install)\n        add_mounts rw \"$OPAM_SWITCH_PREFIX\"\n        add_mounts ro \"$OPAM_SWITCH_PREFIX/.opam-switch\"\n        add_mounts rw \"$PWD\"\n        ;;\n    remove)\n        add_mounts rw \"$OPAM_SWITCH_PREFIX\"\n        add_mounts ro \"$OPAM_SWITCH_PREFIX/.opam-switch\"\n        if [ \"X${PWD#$OPAM_SWITCH_PREFIX/.opam-switch}\" != \"X${PWD}\" ]; then\n          add_mounts rw \"$PWD\"\n        fi\n        ;;\n    *)\n        echo \"$0: unknown command $COMMAND, must be one of 'build', 'install' or 'remove'\" >&2\n        exit 2\nesac\n\nexec sandbox-exec -p \"$POL\" \"$@\"\n"

