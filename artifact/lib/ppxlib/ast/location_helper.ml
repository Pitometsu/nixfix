
let deprecated loc s =
  Ocaml_common.Location.prerr_warning loc (Ocaml_common.Warnings.Deprecated s)


let print_error ppf loc = Ocaml_common.Location.print_error ppf loc
let error_of_printer ~loc x y = Ocaml_common.Location.error_of_printer loc x y

