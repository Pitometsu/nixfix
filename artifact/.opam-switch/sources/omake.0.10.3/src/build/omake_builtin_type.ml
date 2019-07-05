type builtin_fun =
  Omake_env.t -> Omake_value_type.pos -> Lm_location.t -> Omake_value_type.t list -> Omake_value_type.t
type builtin_kfun =
  Omake_env.t -> Omake_value_type.pos -> Lm_location.t -> Omake_value_type.t list -> Omake_value_type.keyword_value list -> Omake_env.t * Omake_value_type.t

type builtin_env_fun = Omake_build_type.t -> builtin_fun

type builtin_object_info = string * Omake_ir.var * Omake_value_type.t

type builtin_rule = bool * string list * string list

type builtin_info =
   { builtin_vars       : (string * (Omake_env.t -> Omake_value_type.t)) list;
     builtin_funs       : (bool * string * builtin_fun * Omake_ir.arity) list;
     builtin_kfuns      : (bool * string * builtin_kfun * Omake_ir.arity) list;
     builtin_objects    : builtin_object_info list;
     pervasives_objects : string list;
     phony_targets      : string list;
     builtin_rules      : builtin_rule list
   }

let builtin_empty =
   { builtin_vars       = [];
     builtin_funs       = [];
     builtin_kfuns      = [];
     builtin_objects    = [];
     pervasives_objects = [];
     phony_targets      = [];
     builtin_rules      = []
   }

