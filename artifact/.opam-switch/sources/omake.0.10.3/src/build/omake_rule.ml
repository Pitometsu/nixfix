(*  Rule evaluation. *)

include Omake_pos.Make (struct let name = "Omake_rule" end);;


type 'a result =
  | Success of 'a
  | Exception of exn

(*
 * Debugging.
 *)
let debug_active_rules =
   Lm_debug.create_debug (**)
      { debug_name = "active-rules";
        debug_description = "Display debugging information for computed rules";
        debug_value = false
      }

(*
 * A data structure to keep sequences of command_info.
 * We can append a command to the current info, or
 * add another entirely new info.
 *)
module type CommandSig =
sig
   type t
   type resume

   (* Create a buffer *)
   val create : 
     Omake_env.t -> Omake_node.Node.t -> 
     Omake_value_type.t -> Omake_node.NodeSet.t -> Omake_node.NodeSet.t -> Omake_node.NodeSet.t -> Omake_node.NodeSet.t -> t

   (* Projections *)
   val target : t -> Omake_node.Node.t * Omake_value_type.t

   (* Adding to the buffer *)
   val add_command  : t -> Omake_value_type.command -> t
   val add_locks    : t -> Omake_node.NodeSet.t -> t
   val add_effects  : t -> Omake_node.NodeSet.t -> t
   val add_scanners : t -> Omake_node.NodeSet.t -> t
   val add_deps     : t -> Omake_node.NodeSet.t -> t

   (* Block operations *)
   val enter  : t -> Omake_env.t -> Omake_node.Node.t list -> Omake_value_type.t list -> resume * t
   val resume : t -> resume -> t

   (* Get the final info *)
   val contents : t -> Omake_node.NodeSet.t * Omake_node.NodeSet.t * Omake_node.NodeSet.t * Omake_node.NodeSet.t * Omake_env.command_info list
end

module Command : CommandSig =
struct
   (*
    * The command buffer.
    *)
   type t =
      { buf_target   : Omake_node.Node.t;
        buf_core     : Omake_value_type.t;
        buf_locks    : Omake_node.NodeSet.t;
        buf_effects  : Omake_node.NodeSet.t;
        buf_deps     : Omake_node.NodeSet.t;
        buf_scanners : Omake_node.NodeSet.t;

        (* The state that is being collected *)
        buf_env      : Omake_env.t;
        buf_sources  : Omake_node.Node.t list;
        buf_values   : Omake_value_type.t list;
        buf_commands : Omake_value_type.command list;

        (* The buffers that have already been collected *)
        buf_info     : Omake_env.command_info list
      }

   type resume = Omake_env.t * Omake_node.Node.t list * Omake_value_type.t list

   (*
    * Create a new command buffer.
    *)
   let create venv target core locks effects deps scanners =
      { buf_target   = target;
        buf_core     = core;
        buf_locks    = locks;
        buf_effects  = effects;
        buf_deps     = deps;
        buf_scanners = scanners;
        buf_env      = venv;
        buf_sources  = [];
        buf_values   = [];
        buf_commands = [];
        buf_info     = []
      }

   (*
    * Projections.
    *)
   let target buf =
      let { buf_target = target;
            buf_core = core;
            _
          } = buf
      in
         target, core

   (*
    * Add a command to the buffer.
    *)
   let add_command buf command =
      { buf with buf_commands = command :: buf.buf_commands }

   let add_locks buf locks =
      { buf with buf_locks = Omake_node.NodeSet.union buf.buf_locks locks }

   let add_effects buf effects =
      { buf with buf_effects = Omake_node.NodeSet.union buf.buf_effects effects }

   let add_deps buf deps =
      { buf with buf_deps = Omake_node.NodeSet.union buf.buf_deps deps }

   let add_scanners buf scanners =
      { buf with buf_scanners = Omake_node.NodeSet.union buf.buf_scanners scanners }

   (*
    * Start a new environment.
    * Return a state that can be used to resume the current environment.
    *)
   let enter buf venv sources values =
      let { buf_env      = venv';
            buf_sources  = sources';
            buf_values   = values';
            buf_commands = commands';
            buf_info     = info';
            _
          } = buf
      in
      let info =
         if commands' = [] && values' = [] then
            info'
         else
            let info =
               { Omake_env.command_env     = venv';
                 command_sources = sources';
                 command_values  = values';
                 command_body    = List.rev commands'
               }
            in
               info :: info'
      in
      let buf =
         { buf with buf_env      = venv;
                    buf_sources  = sources;
                    buf_values   = values;
                    buf_commands = [];
                    buf_info     = info
         }
      in
      let resume = venv', sources', values' in
         resume, buf

   let resume buf (venv, sources, values) =
      snd (enter buf venv sources values)

   (*
    * Get the contents.
    *)
   let contents buf =
      let { buf_env      = venv;
            buf_values   = values;
            buf_sources  = sources;
            buf_locks    = locks;
            buf_effects  = effects;
            buf_scanners = scanners;
            buf_deps     = deps;
            buf_commands = commands;
            buf_info     = info;
            _
          } = buf
      in
      let info =
         if commands = [] && values = [] then
            info
         else
            let info' =
               {Omake_env.command_env     = venv;
                 command_sources = sources;
                 command_values  = values;
                 command_body    = List.rev commands
               }
            in
               info' :: info
      in
      let info = List.rev info in
         locks, effects, deps, scanners, info
end

(*
 * Find a rule in a list.
 *)
let find_rule venv pos loc target names =
   if not (List.exists (Omake_node.Node.equal target) names) then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, StringNodeError ("computed rule does not match target", target)));
   Omake_env.venv_explicit_find venv pos target

(*
 * Check if there are any computed commands.
 *)
let commands_are_computed commands =
   List.exists (fun {Omake_env. command_body = body ; _} ->
         List.exists (fun (command : Omake_value_type.command) ->
               match command with
               | CommandSection _ ->
                     true
                | CommandValue _ ->
                     false) body) commands

(*
 * Expand a single command.
 *)
let rec expand_command venv pos loc buf (command : Omake_value_type.command) =
  let pos = string_pos "expand_command" pos in
  match command with
  | CommandValue _ ->
    Command.add_command buf command
  | CommandSection (arg, fv, el) ->
    if Lm_debug.debug debug_active_rules then
      Format.eprintf "@[<hv 3>section %a@ %a@]@." Omake_value_print.pp_print_value arg 
        Omake_ir_print.pp_print_exp_list el;

    (* The section should be either a rule or eval case *)
    match Lm_string_util.trim (Omake_eval.string_of_value venv pos arg) with
      "" ->
      expand_eval_section venv pos loc buf "eval" fv el
    | "eval" as s ->
      expand_eval_section venv pos loc buf s fv el
    | "rule" ->
      expand_rule_section venv pos loc buf el
    | s ->
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, StringStringError ("invalid section argument, valid arguments are rule, eval", s)))

and expand_commands venv pos loc buf commands =
  match commands with
    command :: commands ->
    let buf = expand_command venv pos loc buf command in
    expand_commands venv pos loc buf commands
  | [] ->
    buf

(*
 * This section computes a new rule for the target.
 *)
and expand_rule_section venv pos loc buf e =
  let pos = string_pos "expand_rule_section" pos in
  let target, core = Command.target buf in
  let venv = Omake_env.venv_explicit_target venv target in
  let venv = Omake_env.venv_add_wild_match venv core in
  let _, v = Omake_eval.eval_sequence_exp venv pos e in
  if Lm_debug.debug debug_active_rules then
    Format.eprintf "@[<v 0>%a@ @[<hv 3>*** omake: rule body returned@ @[<hv 3>%a@]@]@]@." (**)
      Lm_location.pp_print_location loc
      Omake_value_print.pp_print_value v;

  match v with
    ValRules erules ->
    let erule = find_rule venv pos loc target erules in
    let {Omake_env. rule_locks    = locks;
          rule_effects  = effects;
          rule_sources  = deps;
          rule_scanners = scanners;
          rule_commands = commands;
          _
        } = erule
    in
    let buf = Command.add_locks buf locks in
    let buf = Command.add_effects buf effects in
    let buf = Command.add_deps buf deps in
    let buf = Command.add_scanners buf scanners in
    expand_command_info_list pos loc buf commands
  | _ ->
    Format.eprintf "@[<v 0>%a@ *** omake: section rule: did not compute a rule@]@." (**)
      Lm_location.pp_print_location loc;
    buf

(*
 * This section is to be evaluated when the rule is run.
 *)
and expand_eval_section _ pos _ buf s fv e =
  let _pos = string_pos "expand_eval_section" pos in
  Command.add_command buf (CommandSection (ValString s, fv, e))

(*
 * Expand a buf_info list.
 *)
and expand_command_info pos loc buf command =
  match command with {Omake_env. command_env = venv;
                       command_sources = sources;
                       command_values = values;
                       command_body = commands
                     } ->
    let pos = string_pos "expand_buf_info" pos in
    let resume, buf = Command.enter buf venv sources values in
    let buf = expand_commands venv pos loc buf commands in
    Command.resume buf resume

and expand_command_info_list pos loc buf commands =
  let pos = string_pos "expand_buf_info_list" pos in
  List.fold_left (expand_command_info pos loc) buf commands

(*
 * Expand a rule, so that the commands are a command list.
 *)
let expand_rule erule =
  match erule with
    {Omake_env. rule_loc      = loc;
      rule_env      = venv;
      rule_target   = target;
      rule_locks    = locks;
      rule_effects  = effects;
      rule_match    = core;
      rule_sources  = deps;
      rule_scanners = scanners;
      rule_commands = commands;
      _
    } ->
    if commands_are_computed commands then
      let core : Omake_value_type.t =
        match core with
        | Some s ->
          ValData s
        | None ->
          ValNode target
      in
      let pos = string_pos "expand_rule" (loc_exp_pos loc) in
      let buf = Command.create venv target core locks effects deps scanners in
      let buf = expand_command_info_list pos loc buf commands in
      let locks, effects, deps, scanners, commands = Command.contents buf in
      if Lm_debug.debug debug_active_rules then
        Format.eprintf "@[<v 3>expand_rule: %a@ @[<b 3>locks =%a@]@ @[<b 3>effects =%a@]@ @[<b 3>deps = %a@]@ @[<b 3>scanners = %a@]@]@." (**)
          Omake_node.pp_print_node target
          Omake_node.pp_print_node_set locks
          Omake_node.pp_print_node_set effects
          Omake_node.pp_print_node_set deps
          Omake_node.pp_print_node_set scanners;
      { erule with rule_locks = locks;
        rule_effects = effects;
        rule_sources = deps;
        rule_scanners = scanners;
        rule_commands = commands
      }
    else begin
      if Lm_debug.debug debug_active_rules then
        Format.eprintf "@[<v 0>%a@ @[<hv 3>*** omake: static rule@ @[<hv 3>%a@]@]@]@." (**)
          Lm_location.pp_print_location loc
          Omake_env.pp_print_rule erule;
      erule
    end

(************************************************************************
 * Shell utilities.
*)

(*
 * Get the info for the command.
 *)
let eval_shell_info command  = 
   match command with  {  Omake_command_type.command_flags = flags;
         command_dir = dir;
         command_target = target;
         _
       } ->

      flags, dir, target

(*
 * Kill a process.
 *)
let eval_shell_kill venv pos (pid : Omake_env.pid) =
   match pid with
   | ExternalPid pid ->
         Unix.kill pid Sys.sigterm
    | InternalPid pid ->
         Omake_shell_job.kill venv pos pid SigTerm
    | ResultPid _ ->
         ()

(*
 * Wait for a process to exit.
 *)
let eval_shell_wait venv pos pid =
   let pos = string_pos "eval_shell_wait" pos in
   let _, status, value = Omake_shell_job.waitpid venv pos pid in
      status, value

(************************************************************************
 * Globbing.
 *)
let glob_options_of_string options s =
  let len = String.length s in
  let rec search options i =
    if i = len then
      List.rev options
    else
      let options : Lm_glob.glob_option list =
        match s.[i] with
        | 'b' -> GlobNoBraces    :: options
        | 'e' -> GlobNoEscape    :: options
        | 'c'
        | 'n' -> GlobNoCheck     :: options
        | 'i' -> GlobIgnoreCheck :: options
        | 'A'
        | '.' -> GlobDot         :: options
        | 'F' -> GlobOnlyFiles   :: options
        | 'D' -> GlobOnlyDirs    :: options
        | 'C' -> GlobCVSIgnore   :: options
        | 'P' -> GlobProperSubdirs :: options
        | _ -> options
      in
      search options (succ i)
  in
  search options 0

(*
 * Glob an argument into directories and files.
 *)
let glob_arg venv _ _ options arg =
   let cwd = Omake_env.venv_dir venv in
   let dirs, files = Lm_glob.glob options (Omake_node.Dir.fullname cwd) [Omake_command_type.glob_string_of_arg options arg] in
   let dirs = List.sort String.compare dirs in
   let files = List.sort String.compare files in
   let dirs = List.map (fun dir -> Omake_node.Dir.chdir cwd dir) dirs in
   let files = List.map (fun file -> Omake_env.venv_intern_cd venv PhonyProhibited cwd file) files in
      dirs, files

(*
 * This is similar to the above, but we interleave the directories
 * with the files when sorting.
 *)
type glob_result =
   GDir of string
 | GFile of string

let glob_result_compare r1 r2 =
   let s1 =
      match r1 with
         GDir s
       | GFile s ->
            s
   in
   let s2 =
      match r2 with
         GDir s
       | GFile s ->
            s
   in
      -(String.compare s1 s2)

let glob_rev_arg venv _ _ options arg argv =
   let cwd = Omake_env.venv_dir venv in
   let dirs, files = Lm_glob.glob options (Omake_node.Dir.fullname cwd) [Omake_command_type.glob_string_of_arg options arg] in
   let args = List.fold_left (fun args s -> GFile s :: args) [] files in
   let args = List.fold_left (fun args s -> GDir s :: args) args dirs in
   let args = List.sort glob_result_compare args in
      List.fold_left (fun argv arg ->
            let v =
               match arg with
               | GDir s -> Omake_value_type.ValDir (Omake_node.Dir.chdir cwd s)
               | GFile s -> ValNode (Omake_env.venv_intern_cd venv PhonyProhibited cwd s)
            in
               v :: argv) argv args

(*
 * Glob the executable.
 * We do the standard thing, and allow glob expansions to multiple filenames.
 * In this case, the actual command is a bit ambiguous, so users should be
 * careful when they do it.
 *)
let glob_arg_exe venv pos loc options (arg : Omake_command_type.arg) : (Omake_shell_type.simple_exe * Omake_node.Node.t list) =
   if Omake_command_type.is_glob_arg options arg then
      match glob_arg venv pos loc options arg with
         [], exe :: args ->
            ExeNode exe, args
       | [], [] ->
            raise (Omake_value_type.OmakeException (pos, StringError "null glob expansion"))
       | dir :: _, _ ->
            raise (Omake_value_type.OmakeException (pos, StringValueError ("is a directory", ValDir dir)))
   else if Omake_command_type.is_quoted_arg arg then
      ExeQuote (Omake_command_type.simple_string_of_arg arg), []
   else
      Omake_shell_lex.parse_command_string (Omake_command_type.simple_string_of_arg arg), []

let glob_exe venv pos loc options (exe : Omake_command_type.arg Omake_shell_type.cmd_exe) : (Omake_shell_type.simple_exe * Omake_node.Node.t list) =
   match exe with
      CmdNode node ->
         ExeNode node, []
    | CmdArg arg ->
         glob_arg_exe venv pos loc options arg

(*
 * Glob expand the glob arguments.
 *)
let glob_value_argv venv pos loc options argv =
   List.fold_left (fun argv v ->
         if Omake_value.is_glob_value options v then
            let arg = Omake_eval.arg_of_values venv pos [v] in
               glob_rev_arg venv pos loc options arg argv
         else
            v :: argv) [] (List.rev argv)

(*
 * Glob the command line.
 *)
let glob_command_line venv _ _ options argv =
   let cwd = Omake_env.venv_dir venv in
   let dir = Omake_node.Dir.fullname cwd in
   let argv = List.map (Omake_command_type.glob_string_of_arg options) argv in
      Lm_glob.glob_argv options dir argv

(*
 * Glob an input or output file.
 *)
let glob_channel venv pos loc options name =
  match name with
  | Omake_shell_type.RedirectNone
  | RedirectNode _ as file ->
    file
  | RedirectArg name ->
    match glob_arg venv pos loc options name with
      [], [node] ->
      RedirectNode node
    | dir :: _, _ ->
      raise (Omake_value_type.OmakeException (pos, StringValueError ("is a directory", ValDir dir)))
    | [], _ :: _ :: _ ->
      raise (Omake_value_type.OmakeException (pos, StringStringError ("ambiguous redirect", Omake_command_type.simple_string_of_arg name)))
    | [], [] ->
      raise (Omake_value_type.OmakeException (pos, StringStringError ("null redirect", Omake_command_type.simple_string_of_arg name)))

(*
 * Convert the environment strings.
 *)
let string_of_env env =
   List.map (fun (v, arg) ->
         v, Omake_command_type.simple_string_of_arg arg) env

(************************************************************************
 * Alias expansion.
 *)
let find_alias_exn shell_obj venv pos loc exe =
  (* If this is an internal command, create the PipeApply *)
  let name = Lm_symbol.add exe in
  let v = Omake_env.venv_find_field_internal_exn shell_obj name in
  let _, f = Omake_eval.eval_fun venv pos v in

  (* Found the function, no exceptions now *)
  let f venv_orig stdin stdout stderr env argv =
    if !Omake_eval.debug_eval || !Omake_shell_type.debug_shell then
      Format.eprintf "Running %s, stdin=%i, stdout=%i, stderr=%i@." exe (Obj.magic stdin) (Obj.magic stdout) (Obj.magic stderr);
    let venv   = Omake_env.venv_fork venv_orig in
    let venv   = List.fold_left (fun venv (v, s) -> Omake_env.venv_setenv venv v s) venv env in
    let stdin_chan  = Lm_channel.create "<stdin>"  Lm_channel.PipeChannel Lm_channel.InChannel  false (Some stdin) in
    let stdout_chan = Lm_channel.create "<stdout>" Lm_channel.PipeChannel Lm_channel.OutChannel false (Some stdout) in
    let stderr_chan = Lm_channel.create "<stderr>" Lm_channel.PipeChannel Lm_channel.OutChannel false (Some stderr) in
    let stdin  = Omake_env.venv_add_channel venv stdin_chan in
    let stdout = Omake_env.venv_add_channel venv stdout_chan in
    let stderr = Omake_env.venv_add_channel venv stderr_chan in
    let venv   = Omake_env.venv_add_var venv Omake_var.stdin_var  (ValChannel (InChannel,  stdin)) in
    let venv   = Omake_env.venv_add_var venv Omake_var.stdout_var (ValChannel (OutChannel, stdout)) in
    let venv   = Omake_env.venv_add_var venv Omake_var.stderr_var (ValChannel (OutChannel, stderr)) in
    let v : Omake_value_type.t     = ValArray argv in
    let () =
      if !Omake_eval.debug_eval then
        Format.eprintf "normalize_apply: evaluating internal function@."
    in
    let code, venv, value, reraise =
      try
        let venv, v = f venv pos loc [v] [] in
        let code =
          match v with
          | ValOther (ValExitCode code) ->
            code
          | _ ->
            0
        in
        code, venv, v, None
      with
      | Omake_value_type.ExitException (_, code)
      | Omake_value_type.ExitParentException (_, code) as exn ->
        code, venv, ValNone, Some exn
      | Omake_value_type.OmakeException _
      | Omake_value_type.UncaughtException _ as exn ->
        Format.eprintf "%a@." Omake_exn_print.pp_print_exn exn;
        Omake_state.exn_error_code, venv, ValNone, None
      | Unix.Unix_error _
      | Sys_error _
      | Not_found
      | Failure _ as exn ->
        Format.eprintf "%a@." Omake_exn_print.pp_print_exn (Omake_value_type.UncaughtException (pos, exn));
        Omake_state.exn_error_code, venv, ValNone, None
    in

    (*
       * XXX: JYH: we should probably consider combining the unfork
       * with venv_unexport.  This is the only place where we actually
       * need the unexport.
       *)
    let venv = Omake_env.venv_unfork venv venv_orig in
    if !Omake_eval.debug_eval then
      Format.eprintf "normalize_apply: internal function is done: %d, %a@." code 
        Omake_value_print.pp_print_value value;
    Omake_env.venv_close_channel venv pos stdin;
    Omake_env.venv_close_channel venv pos stdout;
    Omake_env.venv_close_channel venv pos stderr;
    match reraise with
      Some exn ->
      raise exn
    | None ->
      code, venv, value
  in
  name, f

let find_alias obj venv pos loc exe =
   try Some (find_alias_exn obj venv pos loc exe) with
      Not_found ->
         None

let find_alias_of_env venv pos =
   try
      let obj = Omake_env.venv_find_var_exn venv Omake_var.shell_object_var in
         match Omake_eval.eval_single_value venv pos obj with
            ValObject obj ->
               find_alias obj
          | _ ->
               raise Not_found
   with
      Not_found ->
         (fun _venv _pos _loc _exe -> None)

(************************************************************************
 * Rule evaluation.
 *)

(*
 * Get the target string if there is a single one.
 *)
let target_of_value venv pos (v : Omake_value_type.t) =
  match v with
  | ValNode node ->
    Omake_value_type.TargetNode node
  | _ ->
    TargetString (Omake_eval.string_of_value venv pos v)

let targets_of_value venv pos v =
   List.map (target_of_value venv pos) (Omake_eval.values_of_value venv pos v)

(* let pp_print_target buf (target : Omake_value_type.target) = *)
(*   match target with *)
(*   | TargetNode node -> *)
(*     Format.fprintf buf "TargetNode %a" Omake_node.pp_print_node node *)
(*   | TargetString s -> *)
(*     Format.fprintf buf "TargetString %s" s *)

(* let pp_print_targets buf targets = *)
(*    List.iter (fun target -> Format.fprintf buf " %a" pp_print_target target) targets *)

(*
 * From Omake_cache.
 *)
let include_fun = Omake_cache.include_fun

(*
 * Collect the different kinds of sources.
 *)
let add_sources sources kind sources' =
   List.fold_left (fun sources source ->
         (kind, source) :: sources) sources sources'

let sources_of_options venv pos loc sources options =
   let options = Omake_value.map_of_value venv pos options in
   let effects, sources, scanners, values =
      Omake_env.venv_map_fold (fun (effects, sources, scanners, values) optname optval ->
            let s = Omake_eval.string_of_value venv pos optname in
            let v = Lm_symbol.add s in
               if Lm_symbol.eq v Omake_symbol.normal_sym then
                  let files = targets_of_value venv pos optval in
                     effects, add_sources sources Omake_node_sig.NodeNormal files, scanners, values
               else if Lm_symbol.eq v Omake_symbol.optional_sym then
                  let files = targets_of_value venv pos optval in
                     effects, add_sources sources NodeOptional files, scanners, values
               else if Lm_symbol.eq v Omake_symbol.exists_sym then
                  let files = targets_of_value venv pos optval in
                     effects, add_sources sources NodeExists files, scanners, values
               else if Lm_symbol.eq v Omake_symbol.squash_sym then
                  let files = targets_of_value venv pos optval in
                     effects, add_sources sources NodeSquashed files, scanners, values
               else if Lm_symbol.eq v Omake_symbol.scanner_sym then
                  let files = targets_of_value venv pos optval in
                     effects, sources, add_sources scanners Omake_node_sig.NodeScanner files, values
               else if Lm_symbol.eq v Omake_symbol.effects_sym then
                  let files = targets_of_value venv pos optval in
                     add_sources effects Omake_node_sig.NodeNormal files, sources, scanners, values
               else if Lm_symbol.eq v Omake_symbol.values_sym then
                  effects, sources, scanners, optval :: values
               else
                  raise (Omake_value_type.OmakeException (loc_pos loc pos, StringVarError ("unknown rule option", v)))) (**)
         ([], sources, [], []) options
   in
      List.rev effects, List.rev sources, List.rev scanners, List.rev values

(*
 * Get the commands.
 *)
let lazy_command venv pos (command : Omake_ir.exp) : Omake_value_type.command =
  match command with
  | SectionExp (_, s, el, _) ->
    let fv = Omake_ir_free_vars.free_vars_exp_list el in
    CommandSection (Omake_eval.eval_string_exp venv pos s, fv, el)
  | ShellExp (loc, s) ->
    CommandValue (loc, Omake_env.venv_get_env venv, s)
  | _ ->
    let fv = Omake_ir_free_vars.free_vars_exp command in
    CommandSection (ValData "eval", fv, [command])

let lazy_commands venv pos commands =
  match Omake_eval.eval_value venv pos commands with
  | ValBody (_, [], [], el, export) ->
    List.map (lazy_command venv pos) el, export
  | _ ->
    raise (Omake_value_type.OmakeFatalErr (pos, Omake_value_type.StringValueError ("unknown rule commands", commands)))

let exp_list_of_commands venv pos commands =
  match Omake_eval.eval_value venv pos commands with
  | ValBody (_, [], [], el, _) ->
    el
  | _ ->
    raise (Omake_value_type.OmakeFatalErr (pos, 
          Omake_value_type.StringValueError ("unknown rule commands", commands)))

(*
 * Evaluate a .STATIC rule.
 *)
let eval_memo_rule_exp venv pos loc multiple is_static key vars target source options body =
   let pos = string_pos "eval_memo_rule_exp" pos in

   (* First, evaluate the parts *)
   let sources = targets_of_value venv pos source in
   let sources = add_sources [] Omake_node_sig.NodeNormal sources in
   let sources = (Omake_node_sig.NodeNormal, Omake_value_type.TargetNode target) :: sources in
   let effects, sources, scanners, values = sources_of_options venv pos loc sources options in
   let el = exp_list_of_commands venv pos body in
   let e : Omake_ir.exp = SequenceExp (loc, el) in

   (* Reject some special flags *)
   let () =
      if effects <> [] || scanners <> [] then
         raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".STATIC rules cannot have effects or scanners"))
   in

   (* Add the rule *)
   let venv = Omake_env.venv_add_memo_rule venv pos loc multiple is_static key vars sources values e in
      venv

(*
 * Evaluate a rule.
 *
 * There are two types of rules.  Implicit rules are 2-place rules that
 * have a % in the target name, or 3-place rules.  Explicit rules are 2-place rules
 * that do not have a %.
 *)
let rec eval_rule_exp venv pos loc multiple target pattern source options body =
  let pos = string_pos "eval_rule_exp" pos in

  (* First, evaluate the parts *)
  let targets  = targets_of_value venv pos target in
  let patterns = targets_of_value venv pos pattern in
  let sources  = targets_of_value venv pos source in
  let sources  = add_sources [] Omake_node_sig.NodeNormal sources in
  let effects, sources, scanners, values = sources_of_options venv pos loc sources options in
  let commands, export = lazy_commands venv pos body in
  let commands_are_nontrivial = commands <> [] in
  (* Process special rules *)
  match targets with
  | [TargetString ".SUBDIRS"] ->
    if effects <> [] || patterns <> [] || scanners <> [] || values <> [] then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".SUBDIRS rule cannot have patterns, effects, scanners, or values"));
    let venv = eval_subdirs_rule venv loc sources (exp_list_of_commands venv pos body) export in
    venv, Omake_value_type.ValNone

  | [TargetString ".PHONY"]  ->
    let targets, sources =
      if patterns = [] then
        List.map snd sources, []
      else
        patterns, sources
    in
    let multiple =
      if multiple then
        Omake_value_type.RuleMultiple
      else
        Omake_value_type.RuleSingle in
    let venv = Omake_env.venv_add_phony venv loc targets in
    if effects <> [] || sources <> [] || scanners <> [] || values <> [] || commands_are_nontrivial then
      let venv, rules = Omake_env.venv_add_rule venv pos loc multiple targets [TargetString "%"] effects sources scanners values commands in
      venv, ValRules rules
    else
      venv, ValNone

  | [TargetString ".SCANNER"] ->
    let targets, sources =
      if patterns = [] then
        List.map snd sources, []
      else
        patterns, sources
    in
    let multiple =
      if multiple then
        Omake_value_type.RuleScannerMultiple
      else
        Omake_value_type.RuleScannerSingle
    in
    let venv, rules = Omake_env.venv_add_rule venv pos loc multiple targets [] effects sources scanners values commands in
    venv, ValRules rules

  | [TargetString ".INCLUDE"] ->
    if effects <> [] || scanners <> [] then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".INCLUDE cannot have effects or scanners"));
    let targets, sources =
      if patterns = [] then
        List.map snd sources, []
      else
        patterns, sources
    in
    let venv = eval_include_rule venv pos loc targets sources values commands in
    venv, ValNone

  | [TargetString ".ORDER"] ->
    if commands_are_nontrivial then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".ORDER rules cannot have build commands"));
    if effects <> [] || patterns <> [] || scanners <> [] || values <> [] then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".ORDER rules cannot have patterns, effects, scanners, or values"));
    let sources = List.map snd sources in
    let venv = Omake_env.venv_add_phony venv loc sources in
    let venv = Omake_env.venv_add_orders venv loc sources in
    venv, ValNone

  (* .ORDER rules are handled specially *)
  | [TargetString name] when Omake_env.venv_is_order venv name ->
    let name = Lm_symbol.add name in
    if commands_are_nontrivial then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".ORDER rule cannot have build commands"));
    if effects <> [] || scanners <> [] || values <> [] then
      raise (Omake_value_type.OmakeException (loc_exp_pos loc, SyntaxError ".ORDER rule cannot have effects, scanners, or values"));
    let venv = eval_ordering_rule venv pos loc name patterns sources in
    venv, ValNone

  | _ ->
    (* Normal rule *)
    let multiple =
      if multiple then
        Omake_value_type.RuleMultiple
      else
        Omake_value_type.RuleSingle
    in
    let venv, rules = Omake_env.venv_add_rule venv pos loc multiple targets patterns effects sources scanners values commands in
    venv, ValRules rules

(*
 * Read the OMakefiles in the subdirectories too.
 *)
and eval_subdirs_rule venv loc sources commands export =
  List.fold_left (fun venv dir -> eval_subdir venv loc dir commands export) venv sources

(*
 * Compile an OMakefile.
 *)
and eval_subdir venv loc (kind, dir) commands export =
  let pos = string_pos "eval_subdir" (loc_exp_pos loc) in
  let cache = Omake_env.venv_cache venv in
  let dir = Omake_env.venv_intern_dir venv  (Omake_env.string_of_target venv dir) in
  let () =
    if kind <> Omake_node_sig.NodeNormal then
      Format.eprintf "*** omake: .SUBDIRS kind %a not implemented@." 
        Omake_node.pp_print_node_kind kind;

    (* Check that the directory exists *)
    if not (Omake_cache.exists_dir cache dir) then
      let create_flag =
        try Omake_eval.bool_of_value venv pos (Omake_env.venv_find_var_exn venv Omake_var.create_subdirs_var) with
          Not_found ->
          false
      in
      if create_flag then
        let name = Omake_node.Dir.fullname dir in
        try Lm_filename_util.mkdirhier name 0o777 with
          Unix.Unix_error _ ->
          raise (Omake_value_type.OmakeException (pos, StringDirError ("can't create directory", dir)))
      else
        raise (Omake_value_type.OmakeException (pos, StringDirError ("directory does not exist", dir)))
  in
  let cwd = Omake_env.venv_dir venv in
  let venv_body = Omake_env.venv_chdir_dir venv loc dir in
  let node = Omake_env.venv_intern venv_body PhonyProhibited Omake_state.makefile_name in
  let venv_body, _ =
    (*
       * Ignore the file if the commands are listed explicity.
       * The OMakefile can always be included explicitly.
       *)
    if commands <> [] then
      Omake_eval.eval_sequence_exp venv_body pos commands

    (* Otherwise, use the file if it exists *)
    else if Omake_cache.exists cache node then
      let venv_body = Omake_env.venv_add_file venv_body node in
      let name = Omake_node.Node.fullname node in
      let loc = Lm_location.bogus_loc name in
      let venv_body = Omake_eval.include_file venv_body IncludeAll pos loc node in
      venv_body, ValNone

    (* Otherwise, check if an empty file is acceptable *)
    else
      let allow_empty_subdirs =
        try Omake_eval.bool_of_value venv_body pos (Omake_env.venv_find_var_exn venv_body Omake_var.allow_empty_subdirs_var) with
          Not_found ->
          false
      in
      if not allow_empty_subdirs then
        raise (Omake_value_type.OmakeException (pos, StringNodeError ("file does not exist", node)));
      venv_body, ValNone
  in

  (*
    * Save the resulting environment as the default to use
    * for targets in this directory.  Also change back to the
    * current directory.
    *)
  let venv =
    Omake_env.venv_add_dir venv_body;
    Omake_env.add_exports venv venv_body pos export
  in
  let venv = Omake_env.venv_chdir_tmp venv cwd in
  if Lm_debug.debug Omake_eval.print_rules then
    Format.eprintf "@[<hv 3>Rules:%a@]@." Omake_env.pp_print_explicit_rules venv;
  venv

(*
 * Include all the sources.
 *)
and eval_include_rule venv pos loc sources deps values commands =
  let pos = string_pos "eval_include_rule" pos in

  (* Targets and dependencies *)
  let target =
    match sources with
      [source] -> Omake_env.venv_intern_target venv PhonyProhibited source
    | _ -> raise (Omake_value_type.OmakeException (pos, StringError ".INCLUDE must have a single source"))
  in
  let venv = Omake_env.venv_add_file venv target in
  let deps = List.map (fun (_, dep) -> Omake_env.venv_intern_target venv PhonyOK dep) deps in

  (* Convert the command list *)
  let commands =
    { Omake_env.command_env = venv;
      Omake_env.command_sources = deps;
      Omake_env.command_values = values;
      Omake_env.command_body = commands
    }
  in
  let commands = eval_commands venv loc target Omake_node.NodeSet.empty [commands] in
  let commands_digest = Omake_command_digest.digest_of_commands pos commands in

  (* Ask the cache if this file is up-to-date *)
  let cache = Omake_env.venv_cache venv in
  let deps = List.fold_left Omake_node.NodeSet.add Omake_node.NodeSet.empty deps in
  let up_to_date = Omake_cache.up_to_date cache include_fun deps commands_digest in
  let () =
    (* Run the commands if there are deps, or if the file does not exist *)
    if commands <> [] && (not up_to_date || Omake_cache.stat cache target = None) then
      exec_commands venv pos loc commands;

    (* Check that it exists *)
    if Omake_cache.force_stat cache target = None then
      raise (Omake_value_type.OmakeException (pos, StringNodeError (".INCLUDE rule failed to build the target", target)));

    (* Tell the cache we did the update *)
    Omake_cache.add cache include_fun target (Omake_node.NodeSet.singleton target) deps commands_digest (MemoSuccess Omake_node.NodeTable.empty) in
  Omake_eval.include_file venv IncludePervasives pos loc target

(*
 * Evaluate the commands NOW.
 *)
and exec_commands venv pos loc commands =
  let stdout = Omake_value.channel_of_var venv pos loc Omake_var.stdout_var in
  let stderr = Omake_value.channel_of_var venv pos loc Omake_var.stderr_var in
  let stdout = Lm_channel.descr stdout in
  let stderr = Lm_channel.descr stderr in
  List.iter (fun command ->
    let pid = eval_shell_internal stdout stderr command in
    let status, _ = eval_shell_wait venv pos pid in
    let code =
      match status with
      | Unix.WEXITED i
      | Unix.WSIGNALED i
      | Unix.WSTOPPED i ->
        i
    in
    if code <> 0 then
      raise (Omake_value_type.OmakeException (pos, StringIntError ("command exited with code", code)))) commands

(*
 * Evaluate the command lines.
 *)
and eval_commands _ loc target sloppy_deps commands : Omake_env.arg_command_line list =
  let rec collect commands' commands =
    match commands with
      command :: commands ->
      let { Omake_env.command_env     = venv;
            Omake_env.command_sources = sources;
            Omake_env.command_values  = values;
            Omake_env.command_body    = body
          } = command
      in
      let lines = eval_rule venv loc target sources sloppy_deps values body in
      let commands' = List.rev_append lines commands' in
      collect commands' commands
    | [] ->
      List.rev commands'
  in
  collect [] commands

(*
 * Evaluate the rule lines.
 * Add these extra variables.
 *   $@: the target file
 *   $*: the target file, without suffix
 *   $>: the target, without the directory part and without suffixes
 *   $<: the first source
 *   $+: all the sources
 *   $^: the sources, in alphabetical order, with duplicates removed
 *   $&: the scanner dependencies from the last run
 *)
and eval_rule venv loc target sources sloppy_deps values commands =
  let pos          = string_pos "eval_rule" (loc_exp_pos loc) in
  let target_name  = Omake_env.venv_nodename venv target in
  let root         = Lm_filename_util.root target_name in
  let root'        = Lm_filename_util.strip_suffixes target_name in
  let venv         = Omake_env.venv_add_var venv Omake_var.star_var (ValData root) in
  let venv         = Omake_env.venv_add_var venv Omake_var.gt_var   (ValData root') in
  let venv         = Omake_env.venv_add_var venv Omake_var.at_var   (ValNode target) in
  let source_all : Omake_value_type.t   = ValArray (List.map (fun v -> Omake_value_type.ValNode v) sources) in
  let source_names = List.map (Omake_env.venv_nodename venv) sources in
  let source_set   = List.fold_left Lm_string_set.LexStringSet.add Lm_string_set.LexStringSet.empty source_names in
  let source_set   = Lm_string_set.LexStringSet.to_list source_set in
  let source_set   = Omake_value_type.ValArray (List.map (fun s -> Omake_value_type.ValData s) source_set) in
  let source : Omake_value_type.t =
    match sources with
    | source :: _ -> ValNode source
    | [] -> ValNone
  in
  let venv = Omake_env.venv_add_var venv Omake_var.plus_var source_all in
  let venv = Omake_env.venv_add_var venv Omake_var.hat_var  source_set in
  let venv = Omake_env.venv_add_var venv Omake_var.lt_var   source in
  let sloppy_deps = List.map (fun v ->Omake_value_type. ValNode v) (Omake_node.NodeSet.to_list sloppy_deps) in
  let venv = Omake_env.venv_add_var venv Omake_var.amp_var  (ValArray sloppy_deps) in
  let options = Lm_glob.create_options (glob_options_of_env venv pos) in
  let find_alias = find_alias_of_env venv pos in
  let command_line (commands, fv) command =
    match (command : Omake_value_type.command) with
    | CommandSection (_, fv', e) ->
      let commands = ([], Omake_command_type.CommandEval e) :: commands in
      let fv = Omake_ir_free_vars.free_vars_union fv fv' in
      commands, fv
    | CommandValue (loc, env, s) ->
      let v = Omake_value_type.ValStringExp (env, s) in
      let commands =
        try
          let flags, pipe = Omake_shell_lex.pipe_of_value venv find_alias options pos loc v in
          (flags, Omake_command_type.CommandPipe pipe) :: commands
        with
          Omake_value_type.OmakeException (_, NullCommand) ->
          commands
      in
      commands, fv
  in
  let commands, fv = List.fold_left command_line ([], Omake_ir_free_vars.free_vars_empty) commands in
  let commands = List.rev commands in
  let values =
    Omake_ir_util.VarInfoSet.fold (fun values v ->
      Omake_value_type.ValMaybeApply (loc, v) :: values) values (Omake_ir_free_vars.free_vars_set fv)
  in
  let values =
    List.fold_left (fun values v ->
      List.rev_append (Omake_eval.values_of_value venv pos v) values) [] values
  in
  let values = List.map (Omake_eval.eval_prim_value venv pos) values in
  let commands =
    if values = [] then
      commands
    else
      ([], CommandValues values) :: commands
  in
  let dir = Omake_env.venv_dir venv in
  Omake_command.parse_commands venv dir target loc commands

(*
 * Add an ordering constraint.
 *)
and eval_ordering_rule venv pos loc name patterns sources =
  let pos = string_pos "eval_ordering_rule" pos in
  let sources = List.map snd sources in
  List.fold_left (fun venv pattern ->
    Omake_env.venv_add_ordering_rule venv pos loc name pattern sources) venv patterns

(************************************************************************
 * Shell.
*)

(*
 * Get globbing options from the environment.
 *)
and glob_options_of_env venv pos =
  let options = [] in
  let options =
    try
      let s = Omake_env.venv_find_var_exn venv Omake_var.glob_options_var in
      let s = Omake_eval.string_of_value venv pos s in
      glob_options_of_string options s
    with
      Not_found ->
      options
  in
  let options : Lm_glob.glob_option list =
    try
      let ignore = Omake_env.venv_find_var_exn venv Omake_var.glob_ignore_var in
      let ignore = Omake_eval.strings_of_value venv pos ignore in
      GlobIgnore ignore :: options
    with
      Not_found -> options
  in
  let options : Lm_glob.glob_option list =
    try
      let allow = Omake_env.venv_find_var_exn venv Omake_var.glob_allow_var in
      let allow = Omake_eval.strings_of_value venv pos allow in
      GlobAllow allow :: options
    with
      Not_found ->
      options
  in
  options

and compile_glob_options venv pos =
  Lm_glob.create_options (glob_options_of_env venv pos)

(*
 * Set the path environment variable.
 *)
and eval_path venv pos =
  let pos = string_pos "eval_path" pos in
  try
    let path = Omake_env.venv_find_var_exn venv Omake_var.path_var in
    let options = Omake_env.venv_options venv in
    let venv' = if Omake_options.opt_absname options then venv else Omake_env.venv_with_options venv 
          ( Omake_options.set_absname_opt options true) in
    let path = Omake_eval.strings_of_value venv' pos path in
    let path = String.concat Lm_filename_util.pathsep path in
    Omake_env.venv_setenv venv Omake_symbol.path_sym path
  with
    Not_found ->
    venv

(*
 * Evaluate a shell expression.
 *)
and eval_shell_exp venv pos loc e =
  let pos    = string_pos "eval_shell_exp" pos in
  let venv   = eval_path venv pos in
  let find_alias = find_alias_of_env venv pos in
  let options = compile_glob_options venv pos in
  let _, pipe = Omake_shell_lex.pipe_of_value venv find_alias options pos loc e in
  let pipe   = normalize_pipe venv pos pipe in
  let stdin  = Omake_value.channel_of_var venv pos loc Omake_var.stdin_var in
  let stdout = Omake_value.channel_of_var venv pos loc Omake_var.stdout_var in
  let stderr = Omake_value.channel_of_var venv pos loc Omake_var.stderr_var in
  let stdin  = Lm_channel.descr stdin in
  let stdout = Lm_channel.descr stdout in
  let stderr = Lm_channel.descr stderr in
  let venv, result = Omake_shell_job.create_job venv pipe stdin stdout stderr in

  (* Get the exit code *)
  let code =
    match result with
      ValInt i
    | ValOther (ValExitCode i) ->
      i
    | _ ->
      0
  in

  (* Check exit code *)
  let exit_on_error =
    try Omake_eval.bool_of_value venv pos (Omake_env.venv_find_var_exn venv Omake_var.abort_on_command_error_var) with
      Not_found ->
      false
  in
  let () =
    if exit_on_error && code <> 0 then
      let print_error buf =
        Format.fprintf buf "@[<hv 3>command terminated with code %d:@ %a@]@." code Omake_env.pp_print_string_pipe pipe
      in
      raise (Omake_value_type.OmakeException (loc_pos loc pos, LazyError print_error))
  in
  venv, result

(*
 * Save the output in a file and return the string.
 *)
and eval_shell_output venv pos loc e =
  let pos = string_pos "eval_shell_output" pos in
  let tmpname = Filename.temp_file "omake" ".shell" in
  let fd = Lm_unix_util.openfile tmpname [Unix.O_RDWR; Unix.O_CREAT; Unix.O_TRUNC] 0o600 in
  let channel = Lm_channel.create tmpname Lm_channel.PipeChannel Lm_channel.OutChannel false (Some fd) in
  let channel = Omake_env.venv_add_channel venv channel in
  let venv = Omake_env.venv_add_var venv Omake_var.stdout_var (ValChannel (OutChannel, channel)) in
  let result =
    try
      let _ = eval_shell_exp venv pos loc e in
      let len = Unix.lseek fd 0 Unix.SEEK_END in
      let _ = Unix.lseek fd 0 Unix.SEEK_SET in
      let data = Bytes.create len in
      Lm_unix_util.really_read fd data 0 len;
      Success (Bytes.to_string data)
    with
      exn ->
      Exception exn  in
  Omake_env.venv_close_channel venv pos channel;
  Unix.unlink tmpname;
  match result with
    Success result ->
    result
  | Exception exn ->
    raise exn

(*
 * Construct a shell.
 *)
and eval_shell venv pos : _ Omake_exec_type.shell =
  let pos = string_pos "eval_shell" pos in
  let venv = eval_path venv pos in
  { shell_eval           = eval_shell_internal;
    shell_eval_is_nop    = eval_shell_is_nop;
    shell_eval_is_cmd    = eval_shell_is_cmd;
    shell_info           = eval_shell_info;
    shell_kill           = eval_shell_kill venv pos;
    shell_wait           = eval_shell_wait venv pos;
    shell_error_value    = ValNone;
    shell_print_exp      = Omake_env.pp_print_arg_command_line;
    shell_print_exn      = Omake_exn_print.pp_print_exn;
    shell_is_failure_exn = Omake_exn_print.is_shell_exn
  }

and eval_shell_is_nop command =
  match command.command_inst with
    | CommandValues _ -> true
    | _ -> false

and eval_shell_is_cmd command =
  match command.command_inst with
    | CommandPipe p -> eval_pipe_is_cmd p
    | _ -> false

and eval_pipe_is_cmd p =
  match p with
    | PipeCommand _ -> true
    | PipeCond(_,_,p1,p2) -> eval_pipe_is_cmd p1 || eval_pipe_is_cmd p2
    | PipeCompose(_,_,p1,p2) -> eval_pipe_is_cmd p1 || eval_pipe_is_cmd p2
    | PipeGroup(_,g) -> eval_pipe_is_cmd g.group_pipe
    | PipeBackground(_,p1) -> eval_pipe_is_cmd p1
    | _ -> false

(*
 * Evaluate a shell command using the internal shell.
 *)
and eval_shell_internal stdout stderr (command : Omake_env.arg_command_line) =
  match command with { Omake_command_type.command_loc  = loc;
                       command_venv = venv;
                       command_inst = inst;
                       _
                     } -> 
    let pos = string_pos "eval_shell_internal" (loc_exp_pos loc) in
    match inst with
      CommandEval e ->
      eval_command venv stdout stderr pos loc e
    | CommandValues _ ->
      ResultPid (0, venv, ValNone)
    | CommandPipe pipe ->
      let pipe = normalize_pipe venv pos pipe in
      let pid =
        if !Omake_eval.debug_eval then
          Format.eprintf "eval_shell_internal: creating job@.";
        Omake_shell_job.create_process venv pipe Unix.stdin stdout stderr
      in
      if !Omake_eval.debug_eval then
        Format.eprintf "eval_shell_internal: created job@.";
      pid

(*
 * Used to evaluate expressions.
 *)
and eval_command venv stdout stderr pos loc e =
  let f stdin stdout stderr =
    if !Omake_eval.debug_eval || !Omake_shell_type.debug_shell then
      Format.eprintf "eval_command: evaluating internal function: stderr = %d@." (Lm_unix_util.int_of_fd stderr);
    let venv   = Omake_env.venv_fork venv in
    let stdin  = Lm_channel.create "<stdin>"  Lm_channel.PipeChannel Lm_channel.InChannel  false (Some stdin) in
    let stdout = Lm_channel.create "<stdout>" Lm_channel.PipeChannel Lm_channel.OutChannel false (Some stdout) in
    let stderr = Lm_channel.create "<stderr>" Lm_channel.PipeChannel Lm_channel.OutChannel false (Some stderr) in
    let stdin  = Omake_env.venv_add_channel venv stdin in
    let stdout = Omake_env.venv_add_channel venv stdout in
    let stderr = Omake_env.venv_add_channel venv stderr in
    let venv   = Omake_env.venv_add_var venv Omake_var.stdin_var  (ValChannel (InChannel,  stdin)) in
    let venv   = Omake_env.venv_add_var venv Omake_var.stdout_var (ValChannel (OutChannel, stdout)) in
    let venv   = Omake_env.venv_add_var venv Omake_var.stderr_var (ValChannel (OutChannel, stderr)) in
    let code =
      try
        (match snd (Omake_eval.eval_sequence_exp venv pos e) with
          ValRules _ ->
          Format.eprintf "@[<hv 3>*** omake warning:@ %a@ Rule value discarded.@]@." (**)
            pp_print_pos (loc_pos loc pos)
        | _ ->
          ());
        0
      with
      | Omake_value_type.ExitException (_, code) ->
        code
      | Omake_value_type.OmakeException _
      | Omake_value_type.UncaughtException _ as exn ->
        Format.eprintf "%a@." Omake_exn_print.pp_print_exn exn;
        Omake_state.exn_error_code
      | Omake_value_type.ExitParentException _
      | Unix.Unix_error _
      | Sys_error _
      | Not_found
      | Failure _ as exn ->
        Format.eprintf "%a@." Omake_exn_print.pp_print_exn 
          (Omake_value_type.UncaughtException (pos, exn));
        Omake_state.exn_error_code
    in
    if !Omake_eval.debug_eval then
      Format.eprintf "eval_command: internal function is done: %d@." code;
    Omake_env.venv_close_channel venv pos stdin;
    Omake_env.venv_close_channel venv pos stdout;
    Omake_env.venv_close_channel venv pos stderr;
    code
  in
  if !Omake_eval.debug_eval then
    Format.eprintf "eval_command: creating thread, stderr = %d@." (Lm_unix_util.int_of_fd stderr);
  Omake_shell_job.create_thread venv f Unix.stdin stdout stderr

(*
 * Normalize the pipe, so the background is only outermost,
 * and translate commands to aliases.
 *
 * The directory must be an absolute name.
 *)
and normalize_pipe venv pos pipe =
  let pos = string_pos "normalize_pipe" pos in
  let options = Lm_glob.create_options (glob_options_of_env venv pos) in
  normalize_pipe_options venv pos false options pipe

and normalize_pipe_options venv pos squash options (pipe : Omake_env.arg_pipe) : Omake_env.string_pipe =
  match pipe with
    PipeApply (loc, apply) ->
    PipeApply (loc, normalize_apply venv pos loc options apply)
  | PipeCommand (loc, command) ->
    PipeCommand (loc, normalize_command venv pos loc options command)
  | PipeCond (loc, op, pipe1, pipe2) ->
    PipeCond (loc, op, (**)
        normalize_pipe_options venv pos true options pipe1,
        normalize_pipe_options venv pos true options pipe2)
  | PipeCompose (loc, divert_stderr, pipe1, pipe2) ->
    PipeCompose (loc, divert_stderr, (**)
        normalize_pipe_options venv pos true options pipe1,
        normalize_pipe_options venv pos true options pipe2)
  | PipeGroup (loc, group) ->
    normalize_group venv pos loc options group
  | PipeBackground (loc, pipe) ->
    let pipe = normalize_pipe_options venv pos true options pipe in
    if squash then
      pipe
    else
      PipeBackground (loc, pipe)

(*
 * Normalize an alias.
 *)
and normalize_apply venv pos loc options apply =
  match apply with {Omake_shell_type. apply_env    = env;
                     apply_args   = argv;
                     apply_stdin  = stdin;
                     apply_stdout = stdout;
                     _
                   } -> 
    { apply with apply_env = string_of_env env;
      apply_args = glob_value_argv venv pos loc options argv;
      apply_stdin = glob_channel venv pos loc options stdin;
      apply_stdout = glob_channel venv pos loc options stdout
    }

(*
 * Normalize a command.
 * Glob-expand the arguments, and normalize the redirect names.
 *)
and normalize_command venv pos loc options command =
  let pos = string_pos "normalize_command" pos in
  match command with { Omake_shell_type. cmd_env    = env;
                       cmd_exe    = exe;
                       cmd_argv   = argv;
                       cmd_stdin  = stdin;
                       cmd_stdout = stdout;
                       _
                     } -> 
    let exe, args = glob_exe venv pos loc options exe in
    let argv = glob_command_line venv pos loc options argv in
    let argv =
      match args with
        [] ->
        argv
      | _ ->
        List.fold_left (fun argv node ->
            Omake_env.venv_nodename venv node :: argv) argv (List.rev args)
    in
    { command with cmd_env = string_of_env env;
      cmd_exe = exe;
      cmd_argv = argv;
      cmd_stdin = glob_channel venv pos loc options stdin;
      cmd_stdout = glob_channel venv pos loc options stdout
    }

(*
 * Normalize a group.
 * Normalize the redirect names.
 *)
and normalize_group venv pos loc options group =
  let pos = string_pos "normalize_group" pos in
  match group with  { group_stdin  = stdin;
                      group_stdout = stdout;
                      group_pipe = pipe;
                      _
                    } -> 
    PipeGroup (loc, { group with group_stdin  = glob_channel venv pos loc options stdin;
                      group_stdout = glob_channel venv pos loc options stdout;
                      group_pipe   = normalize_pipe_options venv pos false options pipe
                    })

