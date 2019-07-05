(**************************************************************************)
(*                                                                        *)
(*    Copyright 2015 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamCompat

type t = {
  debug_level: int;
  verbose_level: int;
  color: [ `Always | `Never | `Auto ];
  utf8: [ `Extended | `Always | `Never | `Auto ];
  disp_status_line: [ `Always | `Never | `Auto ];
  answer: bool option;
  safe_mode: bool;
  log_dir: string;
  keep_log_dir: bool;
  errlog_length: int;
  merged_output: bool;
  use_openssl: bool;
  precise_tracking: bool;
}

type 'a options_fun =
  ?debug_level:int ->
  ?verbose_level:int ->
  ?color:[ `Always | `Never | `Auto ] ->
  ?utf8:[ `Extended | `Always | `Never | `Auto ] ->
  ?disp_status_line:[ `Always | `Never | `Auto ] ->
  ?answer:bool option ->
  ?safe_mode:bool ->
  ?log_dir:string ->
  ?keep_log_dir:bool ->
  ?errlog_length:int ->
  ?merged_output:bool ->
  ?use_openssl:bool ->
  ?precise_tracking:bool ->
  'a

let default = {
  debug_level = 0;
  verbose_level = 0;
  color = `Auto;
  utf8 = `Auto;
  disp_status_line = `Auto;
  answer = None;
  safe_mode = false;
  log_dir =
    (let user = try Unix.getlogin() with Unix.Unix_error _ -> "xxx" in
     let base = Printf.sprintf "opam-%s-%d" user (OpamStubs.getpid()) in
     Filename.(concat (get_temp_dir_name ()) base));
  keep_log_dir = false;
  errlog_length = 12;
  merged_output = true;
  use_openssl = true;
  precise_tracking = false;
}

let setk k t
    ?debug_level
    ?verbose_level
    ?color
    ?utf8
    ?disp_status_line
    ?answer
    ?safe_mode
    ?log_dir
    ?keep_log_dir
    ?errlog_length
    ?merged_output
    ?use_openssl
    ?precise_tracking
  =
  let (+) x opt = match opt with Some x -> x | None -> x in
  k {
    debug_level = t.debug_level + debug_level;
    verbose_level = t.verbose_level + verbose_level;
    color = t.color + color;
    utf8 = t.utf8 + utf8;
    disp_status_line = t.disp_status_line + disp_status_line;
    answer = t.answer + answer;
    safe_mode = t.safe_mode + safe_mode;
    log_dir = t.log_dir + log_dir;
    keep_log_dir = t.keep_log_dir + keep_log_dir;
    errlog_length = t.errlog_length + errlog_length;
    merged_output = t.merged_output + merged_output;
    use_openssl = t.use_openssl + use_openssl;
    precise_tracking = t.precise_tracking + precise_tracking;
  }

let set t = setk (fun x () -> x) t

(* Global configuration reference *)

let r = ref default

let update ?noop:_ = setk (fun cfg () -> r := cfg) !r

let developer = false
