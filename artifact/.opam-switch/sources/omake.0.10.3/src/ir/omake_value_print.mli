
val pp_print_target           : Omake_value_type.target Lm_printf.t
val pp_print_wild_list        : Lm_wild.in_patt list Lm_printf.t 
val pp_print_source_list      : ('a * Omake_value_type.source_core) list Lm_printf.t 
val pp_print_value            : Omake_value_type.t Lm_printf.t
val pp_print_simple_value     : Omake_value_type.t Lm_printf.t
val pp_print_value_list       : Omake_value_type.t list Lm_printf.t
val pp_print_path             : Omake_value_type.path Lm_printf.t
val pp_print_item : Omake_value_type.item Lm_printf.t
val pp_print_exn : Omake_value_type.omake_error Lm_printf.t 

(* Helpers, used in printing and for $(Fun.arity) function *)
val fun_arity : 
  Omake_value_type.keyword_param_value list -> 
  Omake_ir.param list -> Omake_ir.arity


val curry_fun_arity : 
  Omake_value_type.param_value list ->
  Omake_value_type.keyword_param_value list ->
  Omake_ir.param list -> Omake_value_type.keyword_value list -> Omake_ir.arity
