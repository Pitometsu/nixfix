(*---------------------------------------------------------------------------
   Copyright (c) 2018 The b0 programmers. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   b0 v0.0.0
  ---------------------------------------------------------------------------*)

(** Standard library needs.

    Open this module to use it, this only introduces and redefine
    a few standard modules.

    {e v0.0.0 — {{:https://erratique.ch/software/b0 }homepage}} *)

(** {1:std Std} *)

(** {{:http://www.ecma-international.org/publications/standards/Ecma-048.htm}
      ANSI terminal} interaction. *)
module Tty : sig

  (** {1:terminals Terminals} *)

  type t = [ `Dumb | `Term of string ] option
  (** The type for terminals. Either no terminal, a dumb one or
      a named terminal from the [TERM] environment variable. *)

  val of_fd : Unix.file_descr -> t
  (** [of_fd fd] determines the terminal for file descriptor [fd] by
      using {!Unix.isatty}[ fd] and consulting the [TERM] environment
      variable. *)

  (** {1:caps Capabilities} *)

  type cap = [ `None (** No capability. *) | `Ansi (** ANSI terminal. *)  ]
  (** The type for terminal capabilities. Either no capability or
      ANSI capability. *)

  val cap : t -> cap
  (** [cap tty] determines [tty]'s capabilities. *)

  (** {1:style ANSI escapes and styling} *)

  type color =
  [ `Default | `Black | `Red | `Green | `Yellow | `Blue | `Magenta | `Cyan
  | `White ]
  (** The type for ANSI colors. *)

  type style =
  [ `Bold | `Faint | `Italic | `Underline | `Blink of [ `Slow | `Rapid ]
  | `Reverse | `Fg of color | `Bg of color ]
  (** The type for ANSI styles. *)

  val styled_str : cap -> style list -> string -> string
  (** [styled_str cap styles s] styles [s] according to [styles] and [cap]. *)

  val strip_escapes : string -> string
  (** [strip_escapes s] removes ANSI escapes from [s]. *)
end

(** Textual formatters.

    Helpers for dealing with {!Format}. *)
module Fmt : sig

  (** {1:stdoutput Standard outputs and formatters} *)

  val stdout : Format.formatter
  (** [stdout] outputs to standard output. *)

  val stderr : Format.formatter
  (** [stderr] outputs to standard error. *)

  val flush : Format.formatter -> unit
  (** [flush] is {!Format.pp_print_flush}. *)

  (** {1:formatting Formatting} *)

  val pf : Format.formatter -> ('a, Format.formatter, unit) format -> 'a
  (** [pf] is {!Format.fprintf}. *)

  val pr : ('a, Format.formatter, unit) format -> 'a
  (** [pf] is {!Format.printf}. *)

  val epr : ('a, Format.formatter, unit) format -> 'a
  (** [epr] is {!Format.eprintf}. *)

  val str : ('a, Format.formatter, unit, string) format4 -> 'a
  (** str is {!Format.asprintf}. *)

  val kpf :
    (Format.formatter -> 'a) -> Format.formatter ->
    ('b, Format.formatter, unit, 'a) format4 -> 'b
  (** [kpf] is {!Format.kfprintf}. *)

  val kstr : (string -> 'a) -> ('b, Format.formatter, unit, 'a) format4 -> 'b
  (** kstr is {!Format.kasprintf}. *)

  val failwith : ('b, Format.formatter, unit, 'a) format4 -> 'b
  (** [failwith fmt ...] is [kstr (fun s -> failwith s) fmt ...] *)

  val failwith_notrace : ('b, Format.formatter, unit, 'a) format4 -> 'b
  (** [failwith_notrace] is like {!nt} but [Failure] is raised with
      {!raise_notrace}. *)

  val invalid_arg : ('b, Format.formatter, unit, 'a) format4 -> 'b
  (** [invalid_arg fmt ...] is [kstr (fun s -> invalid_arg s) fmt ...] *)

  val error : ('b, Format.formatter , unit, ('a, string) result) format4 -> 'b
  (** [error fmt ...] is [kstr (fun s -> Error s) fmt ...] *)

  (** {1:formatters Formatters} *)

  type 'a t = Format.formatter -> 'a -> unit
  (** The type for formatter of values of type ['a]. *)

  val nop : 'a t
  (** [nop] formats nothing. *)

  val unit : (unit, Format.formatter, unit) Pervasives.format -> unit t
  (** [unit fmt] formats a unit value with the format [fmt]. *)

  val cut : unit t
  (** [cut] is {!Format.pp_print_cut}. *)

  val sp : unit t
  (** [sp] is {!Format.pp_print_space}. *)

  val comma : unit t
  (** [comma] is [unit ",@ "]. *)

  (** {1:basetypes Base type formatters} *)

  val bool : bool t
  (** [bool] is {!Format.pp_print_bool}. *)

  val int : int t
  (** [int] is {!Format.pp_print_int}. *)

  val int32 : int32 t
  (** [int32] is [pf ppf "%ld"]. *)

  val int64 : int64 t
  (** [int64] is [pf ppf "%Ld"]. *)

  val float : float t
  (** [float] is [pf ppf "%g"]. *)

  val char : char t
  (** [char] is {!Format.pp_print_char}. *)

  val string : string t
  (** [string] is {!Format.pp_print_string}. *)

  val elided_string : max:int -> string t
  (** [elieded_string ~max] formats a string using at most [max]
      characters, eliding it if it is too long with three consecutive
      dots which do count towards [max]. *)

  val pair : ?sep:unit t -> 'a t -> 'b t -> ('a * 'b) t
  (** [pair ~sep pp_fst pp_snd] formats a pair. The first and second
      projection are formatted using [pp_fst] and [pp_snd] and are
      separated by [sep] (defaults to {!cut}). *)

  val list : ?empty:unit t -> ?sep:unit t -> 'a t -> 'a list t
  (** [list ~sep pp_v] formats list elements. Each element of the list is
      formatted in order with [pp_v]. Elements are separated by [sep]
      (defaults to {!cut}). If the list is empty, this is [empty]
      (defaults to {!nop}). *)

  val array : ?empty:unit t -> ?sep:unit t -> 'a t -> 'a array t
  (** [array ~sep pp_v] formats array elements. Each element of the
      array is formatted in in order with [pp_v]. Elements are
      seperated by [sep] (defaults to {!cut}). If the array is empty
      this is [empty] (defauls to {!nop}). *)

  val option : ?none:unit t -> 'a t -> 'a option t
  (** [option ~none pp_v] formats an option. The [Some] case uses
      [pp_v] and [None] uses [none] (defaults to {!nop}). *)

  val none : unit t
  (** [none] is [unit "<none>"]. *)

  val iter : ?sep:unit t -> (('a -> unit) -> 'b -> unit) -> 'a t -> 'b t
  (** [iter ~sep iter pp_elt] formats the iterations of [iter] over a
      value using [pp_elt]. Iterations are separated by [sep] (defaults to
      {!cut}). *)

  val iter_bindings :
    ?sep:unit t -> (('a -> 'b -> unit) -> 'c -> unit) -> ('a * 'b) t -> 'c t
  (** [iter_bindings ~sep iter pp_binding] formats the iterations of
      [iter] over a value using [pp_binding]. Iterations are separated
      by [sep] (defaults to {!cut}). *)

  val text : string t
  (** [text] is {!Format.pp_print_text}. *)

  val lines : string t
  (** [lines] formats lines by replacing newlines (['\n']) in the string
      with calls to {!Format.pp_force_newline}. *)

  val exn : exn t
  (** [exn] formats an exception. *)

  val exn_backtrace : (exn * Printexc.raw_backtrace) t
  (** [exn_backtrace] formats an exception backtrace. *)

  val sys_signal : int t
  (** [sys_signal] formats an OCaml {{!Sys.sigabrt}signal number} as
      a C POSIX {{:http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/signal.h.html}constant}
      or ["SIG(%d)"] if the signal number is unknown. *)

  (** {1:boxes Boxes} *)

  val box : ?indent:int -> 'a t -> 'a t
  (** [box ~indent pp ppf] wraps [pp] in a horizontal or vertical box. Break
      hints that lead to a new line add [indent] to the current indentation
      (defaults to [0]). *)

  val hbox : 'a t -> 'a t
  (** [hbox] is like {!box} but is a horizontal box: the line is not split
      in this box (but may be in sub-boxes). *)

  val vbox : ?indent:int -> 'a t -> 'a t
  (** [vbox] is like {!box} but is a vertical box: every break hint leads
      to a new line which adds [indent] to the current indentation
      (default to [0]). *)

  val hvbox : ?indent:int -> 'a t -> 'a t
  (** [hvbox] is like {!box} but is either {!hbox} if its fits on
      a single line or {!vbox} otherwise. *)

  (** {1:quoting Quoting} *)

  val squotes : 'a t -> 'a t
  (** [squotes pp_v] is [pf "'%a'" pp_v] *)

  val dquotes : 'a t -> 'a t
  (** [dquotes pp_v] is [pf "\"%a\"" pp_v] *)

  (** {1:bracks Brackets} *)

  val parens : 'a t -> 'a t
  (** [parens pp_v ppf] is [pf ppf "@[<1>(%a)@]" pp_v]. *)

  val brackets : 'a t -> 'a t
  (** [brackets pp_v ppf] is [pf ppf "@[<1>[%a]@]" pp_v]. *)

  val braces : 'a t -> 'a t
  (** [braces pp_v ppf] is [pf ppf "@[<1>{%a}@]" pp_v]. *)

  (** {1:tty ANSI TTY styling} *)

  val set_tty_styling_cap : Tty.cap -> unit
  (** [set_tty_styling_cap c] sets the global styling capabilities to
      [c]. Affects the output of {!tty_str} and {!tty}. *)

  val tty_styling_cap : unit -> Tty.cap
  (** [tty_styling_cap ()] is the global styling capability. *)

  val tty_string : Tty.style list -> string t
  (** [tty_string styles ppf s] prints [s] on [ppf] according to [styles]
      and the value of {!tty_styling_cap}. *)

  val tty : Tty.style list -> 'a t -> 'a t
  (** [tty styles pp_v ppf v] prints [v] with [pp_v] on [ppf]
      according to [styles] and the value of {!tty_styling_cap}. *)

  (** {1:alts Alternatives} *)

  val one_of : ?empty:unit t -> 'a t -> 'a list t
  (** [one_of ~empty pp_v ppf l] formats according to the length of [l]
      {ul
      {- [0], formats {!empty} (defaults to {!nop}).}
      {- [1], formats the element with [pp_v].}
      {- [2], formats ["either %a or %a"] with the list elements}
      {- [n], formats ["one of %a, ... or %a"] with the list elements}} *)

  val did_you_mean :
    ?pre:unit t -> ?post:unit t -> kind:string -> 'a t -> ('a * 'a list) t
  (** [did_you_mean ~pre kind ~post pp_v] formats a faulty value [v]
      and a list of [hints] that could have been mistaken for
      [v]. [pre] defaults to [unit "Unknown"], [post] to
      {!nop}. Hints are formatted using {!one_of}. *)

  (** {1:fields Fields} *)

  val field : ?style:Tty.style list -> string -> 'a t -> 'a t
  (** [field ~style l pp_v] pretty prints a named field with label [l]
      styled according to [style] (defaults to [[`Fg `Yellow]]),
      using [pp_v] to print the value. *)

  (** {1:mag Magnitudes} *)

  val si_size : scale:int -> string -> int t
  (** [si_size ~scale unit] formats a non negative integer
      representing unit [unit] at scale 10{^scale * 3}, depending on
      its magnitude, using power of 3
      {{:https://www.bipm.org/en/publications/si-brochure/chapter3.html}
      SI prefixes} (i.e. all of them except deca, hector, deci and
      centi). Only US-ASCII characters are used, [µ] (10{^-6}) is
      written using [u].

      [scale] indicates the scale 10{^scale * 3} an integer
      represents, for example [-1] for m[unit] (10{^-3}), [0] for
      [unit] (10{^0}), [1] for [kunit] (10{^3}); it must be in the
      range \[[-8];[8]\] or [Invalid_argument] is raised.

      Except at the maximal yotta scale always tries to show three
      digits of data with trailing fractional zeros omited. Rounds
      towards positive infinity (over approximates).  *)

  val byte_size : int t
  (** [byte_size] is [si_size ~scale:0 "B"]. *)

  val uint64_ns_span : int64 t
  (** [uint64_ns_span] formats an {e unsigned} nanosecond time span
      according to its magnitude using
      {{:http://www.bipm.org/en/publications/si-brochure/chapter3.html}SI
      prefixes} on seconds and
      {{:http://www.bipm.org/en/publications/si-brochure/table6.html}accepted
      non-SI units}. Years are counted in Julian years (365.25
      SI-accepted days) as
      {{:http://www.iau.org/publications/proceedings_rules/units/}defined}
      by the International Astronomical Union (IAU). Only US-ASCII characters
      are used ([us] is used for [µs]). *)
end

(** Option values (as in [4.08)]. *)
module Option : sig

  (** {1:options Options} *)

  type 'a t = 'a option = None | Some of 'a (** *)
  (** The type for option values. Either [None] or a value [Some v]. *)

  val none : 'a option
  (** [none] is [None]. *)

  val some : 'a -> 'a option
  (** [some v] is [Some v]. *)

  val value : 'a option -> default:'a -> 'a
  (** [value o ~default] is [v] if [o] is [Some v] and [default] otherwise. *)

  val get : 'a option -> 'a
  (** [get o] is [v] if [o] is [Some v] and @raise Invalid_argument
      otherwise. *)

  val bind : 'a option -> ('a -> 'b option) -> 'b option
  (** [bind o f] is [Some (f v)] if [o] is [Some v] and [None] if [o] is
      [None]. *)

  val join : 'a option option -> 'a option
  (** [join oo] is [Some v] if [oo] is [Some (Some v)] and [None] otherwise. *)

  val map : ('a -> 'b) -> 'a option -> 'b option
  (** [map f o] is [None] if [o] is [None] and [Some (f v)] is [o] is
      [Some v]. *)

  val fold : none:'a -> some:('b -> 'a) -> 'b option -> 'a
  (** [fold ~none ~some o] is [none] if [o] is [None] and [some v] if [o] is
      [Some v]. *)

  val iter : ('a -> unit) -> 'a option -> unit
  (** [iter f o] is [f v] if [o] is [Some v] and [()] otherwise. *)

  (** {1:preds Predicates and comparisons} *)

  val is_none : 'a option -> bool
  (** [is_none o] is [true] iff [o] is [None]. *)

  val is_some : 'a option -> bool
  (** [is_some o] is [true] iff [o] is [Some o]. *)

  val equal : ('a -> 'a -> bool) -> 'a option -> 'a option -> bool
  (** [equal eq o0 o1] is [true] iff [o0] and [o1] are both [None] or if
      they are [Some v0] and [Some v1] and [eq v0 v1] is [true]. *)

  val compare : ('a -> 'a -> int) -> 'a option -> 'a option -> int
  (** [compare cmp o0 o1] is a total order on options using [cmp] to compare
      values wrapped by [Some _]. [None] is smaller than [Some _] values. *)

  (** {1:converting Converting} *)

  val to_result : none:'e -> 'a option -> ('a, 'e) result
  (** [to_result ~none o] is [Ok v] if [o] is [Some v] and [Error none]
      otherwise. *)

  val to_list : 'a option -> 'a list
  (** [to_list o] is [[]] if [o] is [None] and [[v]] if [o] is [Some v]. *)
end

(** Result values (as in [4.08])

    Except for the function of {{!exn}this section}
    that's the [Result] module that went into [4.08]. *)
module Result : sig

  (** {1:results Results} *)

  type ('a, 'e) t = ('a, 'e) result = Ok of 'a | Error of 'e (** *)
  (** The type for result values. Either a value [Ok v] or an error
      [Error e]. *)

  val ok : 'a -> ('a, 'e) result
  (** [ok v] is [Ok v]. *)

  val error : 'e -> ('a, 'e) result
  (** [error e] is [Error e]. *)

  val value : ('a, 'e) result -> default:'a -> 'a
  (** [value r ~default] is [v] if [r] is [Ok v] and [default] otherwise. *)

  val get_ok : ('a, 'e) result -> 'a
  (** [get_ok r] is [v] if [r] is [Ok v] and @raise Invalid_argument
      otherwise. *)

  val get_error : ('a, 'e) result -> 'e
  (** [get_error r] is [e] if [r] is [Error e] and @raise Invalid_argument
      otherwise. *)

  val bind : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
  (** [bind r f] is [Ok (f v)] if [r] is [Ok v] and [r] if [r] is [Error _]. *)

  val join : (('a, 'e) result, 'e) result -> ('a, 'e) result
  (** [join rr] is [r] if [rr] is [Ok r] and [rr] if [rr] is [Error _]. *)

  val map : ('a -> 'b) -> ('a, 'e) result -> ('b, 'e) result
  (** [map f r] is [Ok (f v)] if [r] is [Ok v] and [r] if [r] is [Error _]. *)

  val map_error : ('e -> 'f) -> ('a, 'e) result -> ('a, 'f) result
  (** [map_error f r] is [Error (f e)] if [r] is [Error e] and [r] if
      [r] is [Ok _]. *)

  val fold : ok:('a -> 'c) -> error:('e -> 'c) -> ('a, 'e) result -> 'c
  (** [fold ~ok ~error r] is [ok v] if [r] is [Ok v] and [error e] if [r]
      is [Error e]. *)

  val iter : ('a -> unit) -> ('a, 'e) result -> unit
  (** [iter f r] is [f v] if [r] is [Ok v] and [()] otherwise. *)

  val iter_error : ('e -> unit) -> ('a, 'e) result -> unit
  (** [iter_error f r] is [f e] if [r] is [Error e] and [()] otherwise. *)

  (** {1:preds Predicates and comparisons} *)

  val is_ok : ('a, 'e) result -> bool
  (** [is_ok r] is [true] iff [r] is [Ok _]. *)

  val is_error : ('a, 'e) result -> bool
  (** [is_error r] is [true] iff [r] is [Error _]. *)

  val equal :
    ok:('a -> 'a -> bool) -> error:('e -> 'e -> bool) -> ('a, 'e) result ->
    ('a, 'e) result -> bool
  (** [equal ~ok ~error r0 r1] tests equality of [r0] and [r1] using [ok]
      and [error] to respectively compare values wrapped by [Ok _] and
      [Error _]. *)

  val compare :
    ok:('a -> 'a -> int) -> error:('e -> 'e -> int) -> ('a, 'e) result ->
    ('a, 'e) result -> int
  (** [compare ~ok ~error r0 r1] totally orders [r0] and [r1] using [ok] and
      [error] to respectively compare values wrapped by [Ok _ ] and [Error _].
      [Ok _] values are smaller than [Error _] values. *)

  (** {1:exn Interacting with {!Stdlib} exceptions} *)

  val to_failure : ('a, string) result -> 'a
  (** [to_failure r] is [failwith e] if [r] is [Error e] and [v]
      if [r] is [Ok v]. *)

  val catch_failure : (unit -> 'a) -> ('a, string) result
  (** [catch_failure f] is [try Ok (f ()) with Failure e -> Error e] *)

  val catch_sys_error : (unit -> 'a) -> ('a, string) result
  (** [catch_sys_error f] is [try Ok (f ()) with Sys_error e -> Error e] *)

  (** {1:converting Converting} *)

  val to_option : ('a, 'e) result -> 'a option
  (** [to_option r] is [r] as an option, mapping [Ok v] to [Some v] and
      [Error _] to [None]. *)

  val to_list : ('a, 'e) result -> 'a list
  (** [to_list r] is [[v]] if [r] is [Ok v] and [[]] otherwise. *)
end

(** Characters (bytes in fact). *)
module Char : sig

  include module type of Char

  (** {1:ascii Bytes as US-ASCII characters} *)

  (** US-ASCII character support.

      The following functions act only on US-ASCII code points, that
      is on the bytes in range \[[0x00];[0x7F]\]. The functions can be
      safely used on UTF-8 encoded strings, they will of course only
      deal with US-ASCII related matters.

      {b References.}
      {ul
      {- Vint Cerf.
      {{:http://tools.ietf.org/html/rfc20}
      {e ASCII format for Network Interchange}}. RFC 20, 1969.}} *)
  module Ascii : sig

    (** {1:digits Decimal and hexadecimal digits} *)

    val is_digit : char -> bool
    (** [is_digit c] is [true] iff [c] is an US-ASCII digit
        ['0'] ... ['9'], that is a byte in the range \[[0x30];[0x39]\]. *)

    val is_hex_digit : char -> bool
    (** [is_hex_digit c] is [true] iff [c] is an US-ASCII hexadecimal
        digit ['0'] ... ['9'], ['a'] ... ['f'], ['A'] ... ['F'],
        that is a byte in one of the ranges \[[0x30];[0x39]\],
        \[[0x41];[0x46]\], \[[0x61];[0x66]\]. *)

    val hex_digit_value : char -> int
    (** [hex_digit_value c] is the numerical value of a digit that
        satisfies {!is_hex_digit}. @raise Invalid_argument if
        [is_hex_digit c] is [false]. *)

    val lower_hex_digit : int -> char
    (** [lower_hex_digit n] is an hexadecimal digit for the integer
        [n] truncated to its lowest 4 bits. *)

    val upper_hex_digit : int -> char
    (** [upper_hex_digit n] is an hexadecimal digit for the integer
        [n] truncated to its lowest 4 bits. *)

    (** {1:preds Predicates} *)

    val is_valid : char -> bool
    (** [is_valid c] is [true] iff [c] is an US-ASCII character,
        that is a byte in the range \[[0x00];[0x7F]\]. *)

    val is_upper : char -> bool
    (** [is_upper c] is [true] iff [c] is an US-ASCII uppercase
        letter ['A'] ... ['Z'], that is a byte in the range
        \[[0x41];[0x5A]\]. *)

    val is_lower : char -> bool
    (** [is_lower c] is [true] iff [c] is an US-ASCII lowercase
        letter ['a'] ... ['z'], that is a byte in the range
        \[[0x61];[0x7A]\]. *)

    val is_letter : char -> bool
    (** [is_letter c] is [is_lower c || is_upper c]. *)

    val is_alphanum : char -> bool
    (** [is_alphanum c] is [is_letter c || is_digit c]. *)

    val is_white : char -> bool
    (** [is_white c] is [true] iff [c] is an US-ASCII white space
        character, that is one of space [' '] ([0x20]), tab ['\t']
        ([0x09]), newline ['\n'] ([0x0A]), vertical tab ([0x0B]), form
        feed ([0x0C]), carriage return ['\r'] ([0x0D]). *)

    val is_blank : char -> bool
    (** [is_blank c] is [true] iff [c] is an US-ASCII blank character,
        that is either space [' '] ([0x20]) or tab ['\t'] ([0x09]). *)

    val is_graphic : char -> bool
    (** [is_graphic c] is [true] iff [c] is an US-ASCII graphic
        character that is a byte in the range \[[0x21];[0x7E]\]. *)

    val is_print : char -> bool
    (** [is_print c] is [is_graphic c || c = ' ']. *)

    val is_control : char -> bool
    (** [is_control c] is [true] iff [c] is an US-ASCII control character,
        that is a byte in the range \[[0x00];[0x1F]\] or [0x7F]. *)

    (** {1:case Casing transforms} *)

    val uppercase : char -> char
    (** [uppercase c] is [c] with US-ASCII characters ['a'] to ['z'] mapped
        to ['A'] to ['Z']. *)

    val lowercase : char -> char
    (** [lowercase c] is [c] with US-ASCII characters ['A'] to ['Z'] mapped
        to ['a'] to ['z']. *)
  end
end

(** Strings. *)
module String : sig

  (** {1:string String} *)

  include module type of String

  val empty : string
  (** [empty] is [""]. *)

  val head : string -> char option
  (** [head s] if [Some s.[0]] if [s <> ""] and [None] otherwise. *)

  val of_char : char -> string
  (** [of_char c] is [c] as a string. *)

  (** {1:preds Predicates} *)

  val is_empty : string -> bool
  (** [is_empty s] is [equal empty s]. *)

  val is_prefix : affix:string -> string -> bool
  (** [is_prefix ~affix s] is [true] iff [affix.[i] = s.[i]] for
      all indices [i] of [affix]. *)

  val is_infix : affix:string -> string -> bool
  (** [is_infix ~affix s] is [true] iff there exists an index [j]
      such that for all indices [i] of [affix], [affix.[i] = s.[j+ 1]]. *)

  val is_suffix : affix:string -> string -> bool
  (** [is_suffix ~affix s] is true iff [affix.[i] = s.[m - i]] for all
      indices [i] of [affix] and with [m = String.length s - 1]. *)

  val for_all : (char -> bool) -> string -> bool
  (** [for_all p s] is [true] iff for all indices [i] of [s], [p s.[i]
      = true]. *)

  val exists : (char -> bool) -> string -> bool
  (** [exists p s] is [true] iff there exists an index [i] of [s] with
      [p s.[i] = true]. *)

  (** {1:subs Extracting substrings} *)

  val with_index_range : ?first:int -> ?last:int -> string -> string
  (** [with_index_range ~first ~last s] are the consecutive bytes of [s]
      whose indices exist in the range \[[first];[last]\].

      [first] defaults to [0] and last to [String.length s - 1].

      Note that both [first] and [last] can be any integer. If
      [first > last] the interval is empty and the empty string is
      returned. *)

  (** {1:break Breaking} *)

  (** {2:break_mag Breaking with magnitudes} *)

  val take_left : int -> string -> string
  (** [take_left n s] are the first [n] bytes of [s]. This is [s] if
      [n >= length s] and [""] if [n <= 0]. *)

  val take_right : int -> string -> string
  (** [take_right n s] are the last [n] bytes of [s].  This is [s] if
      [n >= length s] and [""] if [n <= 0]. *)

  val drop_left : int -> string -> string
  (** [drop_left n s] is [s] without the first [n] bytes of [s]. This is [""]
      if [n >= length s] and [s] if [n <= 0]. *)

  val drop_right : int -> string -> string
  (** [drop_right n s] is [s] without the last [n] bytes of [s]. This is [""]
      if [n >= length s] and [s] if [n <= 0]. *)

  val break_left : int -> string -> string * string
  (** [break_left n v] is [(take_left n v, drop_left n v)]. *)

  val break_right : int -> string -> string * string
  (** [break_right n v] is [(drop_left n v, take_right n v)]. *)

  (** {2:break_pred Breaking with predicates} *)

  val keep_left : (char -> bool) -> string -> string
  (** [keep_left sat s] are the first consecutive [sat] statisfying
      bytes of [s]. *)

  val keep_right : (char -> bool) -> string -> string
  (** [keep_right sat s] are the last consecutive [sat] satisfying
      bytes of [s]. *)

  val lose_left : (char -> bool) -> string -> string
  (** [lose_left sat s] is [s] without the first consecutive [sat]
      satisfying bytes of [s]. *)

  val lose_right : (char -> bool) -> string -> string
  (** [lose_right sat s] is [s] without the last consecutive [sat]
      satisfying bytes of [s]. *)

  val span_left : (char -> bool) -> string -> string * string
  (** [span_left sat s] is [(keep_left sat s, lose_left sat s)]. *)

  val span_right : (char -> bool) -> string -> string * string
  (** [span_right sat s] is [(lose_right sat s, keep_right sat s)]. *)

  (** {2:break_sep Breaking with separators} *)

  val cut_left : sep:string -> string -> (string * string) option
  (** [cut ~sep s] is either the pair [Some (l,r)] of the two
      (possibly empty) substrings of [s] that are delimited by the
      first match of the separator character [sep] or [None] if
      [sep] can't be matched in [s]. Matching starts from the
      left of [s].

      The invariant [l ^ sep ^ r = s] holds.

      @raise Invalid_argument if [sep] is the empty string. *)

  val cut_right : sep:string -> string -> (string * string) option
  (** [cut_right ~sep s] is like {!cut_left} but matching starts
      on the right of [s]. *)

  val cuts_left : ?drop_empty:bool -> sep:string -> string -> string list
  (** [cuts_left sep s] is the list of all substrings of [s] that are
      delimited by matches of the non empty separator string
      [sep]. Empty substrings are omitted in the list if [drop_empty]
      is [true] (defaults to [false]).

      Matching separators in [s] starts from the left of [s] ([rev] is
      [false], default) or the end ([rev] is [true]). Once one is
      found, the separator is skipped and matching starts again, that
      is separator matches can't overlap. If there is no separator
      match in [s], the list [[s]] is returned.

      The following invariants hold:
      {ul
      {- [concat ~sep (cuts ~drop_empty:false ~sep s) = s]}
      {- [cuts ~drop_empty:false ~sep s <> []]}}

      @raise Invalid_argument if [sep] is the empty string. *)

  val cuts_right : ?drop_empty:bool -> sep:string -> string -> string list
  (** [cuts_right sep s] is like {!cuts_left} but matching starts on the
      right of [s]. *)

  (** {1:traversing Traversing} *)

  val map : (char -> char) -> string -> string
  (** [map f s] is [s'] with [s'.[i] = f s.[i]] for all indices [i] of
      [s]. [f] is invoked in increasing index order. *)

  val mapi : (int -> char -> char) -> string -> string
  (** [mapi f s] is [s'] with [s'.[i] = f i s.[i]] for all indices [i]
      of [s]. [f] is invoked in increasing index order. *)

  (** {1:fmt Formatting} *)

  val pp : string Fmt.t
  (** [pp ppf s] prints [s]'s bytes on [ppf]. *)

  val dump : string Fmt.t
  (** [dump ppf s] prints [s] as a syntactically valid OCaml string
      on [ppf]. *)

  (** {1:unique Uniqueness} *)

  val uniquify : string list -> string list
  (** [uniquify ss] is [ss] without duplicates, the list order is
      preserved. *)

  val unique :
    exists:(string -> bool) -> string -> (string, string) result
  (** [unique ~exist n] is [n] if [exists n] is [false] or [r = strf
      "%s~%d" n d] with [d] the smallest integer in \[[1];[1e9]\] such
      that [exists r] is [false] or an error if there is no such
      string. *)

  (** {1:suggesting Suggesting} *)

  val edit_distance : string -> string -> int
  (** [edit_distance s0 s1] is the number of single character edits (insertion,
      deletion, substitution) that are needed to change [s0] into [s1]. *)

  val suggest : ?dist:int -> string list -> string -> string list
  (** [suggest ~dist candidates s] are the elements of [candidates]
      whose {{!edit_distance}edit distance} is the smallest to [s] and
      at most at a distance of [dist] of [s] (defaults to [2]). If
      multiple results are returned the order of [candidates] is
      preserved. *)

  (** {1:escunesc Escaping and unescaping bytes}

      See also the {!Ascii.escunesc}.

      {b XXX.} Limitation cannot escape/unescape multiple bytes (e.g.
      UTF-8 byte sequences). This could be achieved by tweaking
      the sigs to return integer pairs but that would allocate
      quite a bit. *)

  val escaper :
    (char -> int) -> (bytes -> int -> char -> int) -> string -> string
  (** [escaper char_len set_char] is a byte escaper that given a
       byte [c] uses [char_len c] bytes in the escaped form and
       uses [set_char b i c] to set the escaped form for [c] in [b] at
       index [i] returning the next writable index (no bounds
       check need to be performed). For any [b], [c] and [i] the
       invariant [i + char_len c = set_char b i c] must hold. *)

  exception Illegal_escape of int
  (** See {!unescaper}. *)

  val unescaper :
    (string -> int -> int) -> (bytes -> int -> string -> int -> int) ->
    string -> (string, int) result
  (** [unescaper char_len_at set_char] is a byte unescaper that uses
      [char_len_at] to determine the length of a byte at a given index
      in the string to unescape and [set_char b k s i] to set at index
      [k] in [b] the unescaped character read at index [i] in [s]; and
      returns the next readable index in [s] (no bound check need
      to be performed). For any [b], [s], [k] and [i] the invariant [i
      + char_len_at s i = set_char b k s i].

      Both [char_len_at] and [set_char] may raise [Illegal_escape i]
      if the given index [i] has an illegal or truncated escape.  The
      unescaper only uses this exception internally it returns [Error
      i] if it found an illegal escape at index [i]. *)

  (** {1:ascii Strings as US-ASCII character sequences} *)

  (** US-ASCII string support.

      The following functions act only on US-ASCII code points, that
      is on the bytes in range \[[0x00];[0x7F]\]. The functions can be
      safely used on UTF-8 encoded strings but they will, of course,
      only deal with US-ASCII related matters.

      {b References.}
      {ul
      {- Vint Cerf.
      {{:http://tools.ietf.org/html/rfc20}
      {e ASCII format for Network Interchange}}. RFC 20, 1969.}} *)
  module Ascii : sig

    (** {1:pred Predicates} *)

    val is_valid : string -> bool
    (** [is_valid s] is [true] iff only for all indices [i] of [s],
        [s.[i]] is an US-ASCII character, i.e. a byte in the range
        \[[0x00];[0x1F]\]. *)

    (** {1:case Casing transforms}

        The functions can be safely used on UTF-8 encoded strings;
        they will of course only deal with US-ASCII casings. *)

    val uppercase : string -> string
    (** [uppercase s] is [s] with US-ASCII characters ['a'] to ['z'] mapped
        to ['A'] to ['Z']. *)

    val lowercase : string -> string
    (** [lowercase s] is [s] with US-ASCII characters ['A'] to ['Z'] mapped
        to ['a'] to ['z']. *)

    val capitalize : string -> string
    (** [capitalize s] is like {!uppercase} but performs the map only
        on [s.[0]]. *)

    val uncapitalize : string -> string
    (** [uncapitalize s] is like {!lowercase} but performs the map only
        on [s.[0]]. *)

    (** {1:hex Converting to US-ASCII hexadecimal characters} *)

    val to_hex : string -> string
    (** [to_hex s] is the sequence of bytes of [s] as US-ASCII lowercase
        hexadecimal digits. *)

    val of_hex : string -> (string, int) result
    (** [of_hex h] parses a sequence of US-ASCII (lower or upper
        cased) hexadecimal digits from [h] into its corresponding byte
        sequence.  [Error n] is returned either with [n] an index in
        the string which is not a hexadecimal digit or the length of
        [h] if it there is a missing digit at the end. *)

    (** {1:escunesc Converting to printable US-ASCII characters} *)

    val escape : string -> string
    (** [escape s] escapes bytes of [s] to a representation that uses only
        US-ASCII printable characters. More precisely:
        {ul
        {- \[[0x20];[0x5B]\] and \[[0x5D];[0x7E]\] are left unchanged.
           These are the {{!Char.Ascii.is_print}printable} US-ASCII bytes,
           except ['\\'] ([0x5C]).}
        {- \[[0x00];[0x1F]\], [0x5C] and
           \[[0x7F];[0xFF]\] are escaped by an {e hexadecimal} ["\xHH"]
           escape with [H] a capital hexadecimal number. These bytes
           are the US-ASCII control characters, the non US-ASCII bytes
           and ['\\'] ([0x5C]).}}
        Use {!unescape} to unescape. The invariant
        [unescape (escape s) = Ok s] holds. *)

    val unescape : string -> (string, int) result
    (** [unescape s] unescapes from [s] the escapes performed by {!escape}.
        More precisely:
        {ul
        {- ["\xHH"] with [H] a lower or upper case hexadecimal number
           is unescaped to the corresponding byte value.}}
        Any other escape following a ['\\'] not defined above makes
        the function return [Error i] with [i] the index of the
        error in the string. *)

    val ocaml_string_escape : string -> string
    (** [ocaml_string_escape s] escapes the bytes of [s] to a representation
        that uses only US-ASCII printable characters and according to OCaml's
        conventions for [string] literals. More precisely:
        {ul
        {- ['\b'] ([0x08]) is escaped to ["\\b"] ([0x5C,0x62]).}
        {- ['\t'] ([0x09]) is escaped to ["\\t"] ([0x5C,0x74]).}
        {- ['\n'] ([0x0A]) is escaped to ["\\n"] ([0x5C,0x6E]).}
        {- ['\r'] ([0x0D]) is escaped to ["\\r"] ([0x5C,0x72]).}
        {- ['\"'] ([0x22]) is escaped to ["\\\""] ([0x5C,0x22]).}
        {- ['\\'] ([0x5C]) is escaped to ["\\\\"] ([0x5C],[0x5C]).}
        {- [0x20], [0x21], \[[0x23];[0x5B]\] and \[[0x5D];[0x7E]\] are
           left unchanged. These are the
           {{!Char.Ascii.is_print}printable} US-ASCII bytes, except
           ['\"'] ([0x22]) and ['\\'] ([0x5C]).}
        {- Remaining bytes are escaped by an {e hexadecimal} ["\xHH"]
           escape with [H] an uppercase hexadecimal number. These bytes
           are the US-ASCII control characters not mentioned above
           and non US-ASCII bytes.}}
        Use {!ocaml_unescape} to unescape. The invariant
        [ocaml_unescape (ocaml_string_escape s) = Ok s]
        holds. *)

    val ocaml_unescape : string -> (string, int) result
    (** [ocaml_unescape s] unescapes from [s] the escape sequences
        afforded by OCaml [string] and [char] literals. More precisely:
        {ul
        {- ["\\b"] ([0x5C,0x62]) is unescaped to ['\b'] ([0x08]).}
        {- ["\\t"] ([0x5C,0x74]) is unescaped to ['\t'] ([0x09]).}
        {- ["\\n"] ([0x5C,0x6E]) is unescaped to ['\n'] ([0x0A]).}
        {- ["\\r"] ([0x5C,0x72]) is unescaped to ['\r'] ([0x0D]).}
        {- ["\\ "] ([0x5C,0x20]) is unescaped to [' '] ([0x20]).}
        {- ["\\\""] ([0x5C,0x22]) is unescaped to ['\"'] ([0x22]).}
        {- ["\\'"] ([0x5C,0x27]) is unescaped to ['\''] ([0x27]).}
        {- ["\\\\"] ([0x5C],[0x5C]) is unescaped to ['\\'] ([0x5C]).}
        {- ["\xHH"] with [H] a lower or upper case hexadecimal number
           is unescaped to the corresponding byte value.}
        {- ["\\DDD"] with [D] a decimal number such that [DDD]
           is unescaped to the corresponding byte value.}
        {- ["\\oOOO"] with [O] an octal number is unescaped to the
           corresponding byte value.}}

        Any other escape following a ['\\'] not defined above makes
        the function return [Error i] with [i] the location of the
        error in the string. *)
  end

  (** {1:setmap String map and sets} *)

  (** String sets. *)
  module Set : sig

    (** {1 String sets} *)

    include Set.S with type elt := string

    val pp : ?sep:unit Fmt.t -> string Fmt.t -> t Fmt.t
    (** [pp ~sep pp_elt ppf ss] formats the elements of [ss] on
        [ppf]. Each element is formatted with [pp_elt] and elements
        are separated by [~sep] (defaults to
        {!Format.pp_print_cut}). If the set is empty leaves [ppf]
        untouched. *)

    val dump : t Fmt.t
    (** [dump ppf ss] prints an unspecified representation of [ss] on
        [ppf]. *)
  end

  (** String maps. *)
  module Map : sig

    (** {1 String maps} *)

    include Map.S with type key := string

    val dom : 'a t -> Set.t
    (** [dom m] is the domain of [m]. *)

    val of_list : (string * 'a) list -> 'a t
    (** [of_list bs] is [List.fold_left (fun m (k, v) -> add k v m) empty
        bs]. *)

    val pp : ?sep:unit Fmt.t -> (string * 'a) Fmt.t -> 'a t Fmt.t
    (** [pp ~sep pp_binding ppf m] formats the bindings of [m] on
        [ppf]. Each binding is formatted with [pp_binding] and
        bindings are separated by [sep] (defaults to
        {!Format.pp_print_cut}). If the map is empty leaves [ppf]
        untouched. *)

    val dump : 'a Fmt.t -> 'a t Fmt.t
    (** [dump pp_v ppf m] prints an unspecified representation of [m] on
        [ppf] using [pp_v] to print the map codomain elements. *)

    val dump_string_map : string t Fmt.t
    (** [dump_string_map ppf m] prints an unspecified representation of the
        string map [m] on [ppf]. *)
  end
end

(** Lists. *)
module List : sig

  include module type of List


  val classify :
    ?cmp_elts:('a -> 'a -> int) ->
    ?cmp_classes:('b -> 'b -> int) -> classes:('a -> 'b list) -> 'a list ->
    ('b * 'a list) list
  (** [classify ~cmp_elts ~cmp_classes ~classes els] bins elements [els]
      into classes as determined by [classes]. [cmp_elts] is used to
      compare elements and [cmp_classes] to compare classes, both
      default to {!Pervasives.compare}. *)
end

(** Value converters.

    A value converter describes how to encode and decode OCaml values
    to a binary presentation and a textual, human specifiable,
    {{!sexp_syntax}s-expression based}, representation.

    {b Notation.} Given a value [v] and a converter [c] we write
    \[[v]\]{_c} the textual encoding of [v] according to [c]. *)
module Conv : sig

  (** {1:low_codec Low-level encoders and decoders} *)

  exception Error of int * int * string
  (** The exception for conversion errors. This exception is raised
      both by encoders and decoders with {!raise_notrace}. The
      integers indicates a byte index range in the input on decoding
      errors, it is meaningless on encoding ones.

      {b Note.} This exception is used for defining
      converters. High-level {{!convert}converting functions} do not
      raise but use result values to report errors. *)

  (** Binary codecs. *)
  module Bin : sig

    (** {1:enc Encoding} *)

    type 'a enc = Buffer.t -> 'a -> unit
    (** The type for binary encoders. [enc b v] binary encodes the
        value [v] in [b]. Raises {!Error} in case of error. *)

    val enc_err :
      kind:string -> ('a, Format.formatter, unit, 'b) format4 -> 'a
    (** [enc_err ~kind fmt] raises a binary encoding error message for kind
        [kind] formatted according to [fmt]. *)

    val enc_byte : int enc
    (** [enc_byte] encodes an integer in range \[0;255\]. *)

    val enc_bytes : string enc
    (** [enc_bytes] encodes the given bytes. *)

    val enc_list : 'a enc -> 'a list enc
    (** [enc_list enc_v] encodes a list of values encoded with [enc_v]. *)

    (** {1:dec Decoding} *)

    type 'a dec = string -> start:int -> int * 'a
    (** The type for binary decoders. [dec s ~start] binary decodes
        a value at [start] in [s]. [start] is either the index of a byte
        in [s] or the length of [s].  The function returns [(i, v)] with
        [v] the decoded value and [i] the first index in [s] after the
        decoded value or the length of [s] if there is no such
        index. Raises {!Error} in case of error. *)

    val dec_err :
      kind:string -> int -> ('a, Format.formatter, unit, 'b) format4 -> 'a
    (** [dec_err ~kind i fmt] raises a binary decoding error message
        for kind [kind] at input byte index [i] formatted according to [fmt]. *)

    val dec_err_eoi : kind:string -> int -> 'a
    (** [dec_err_eoi ~kind i] raises a decoding error message for kind
        [kind] at input byte index [i] indicating an unexpected end of input. *)

    val dec_err_exceed : kind:string -> int -> int -> max:int -> 'a
    (** [dec_err_exceed ~kind i v ~max] raises a decoding error message
        for kind [kind] at input byte index [i] indicating [v] is not
        in the range [0;max]. *)

    val dec_need : kind:string -> string -> start:int -> len:int -> unit
    (** [dec_need ~kind s ~start ~len] checks that [len] bytes are
        available starting at [start] (which can be out of bounds) in
        [s] and calls {!err_eoi} if that is not the case. *)

    val dec_byte : kind:string -> int dec
    (** [dec_byte] decodes an integer in range \[0;255\] for the
        given [kind]. *)

    val dec_bytes : kind:string -> string dec
    (** [dec_bytes ~kind] decodes the given bytes for the given
        [kind]. *)

    val dec_list : 'a dec -> kind:string -> 'a list dec
    (** [bin_dec_list dec_v ~kind] decodes a list of values decoded with
        [dec_v] for the given [kind]. *)
  end

  (** Textual codecs *)
  module Txt : sig

    (** {1:codec Textual encoders and decoders} *)

    type 'a enc = Format.formatter -> 'a -> unit
    (** The type for textual encoders. [enc ppf v] textually encodes
        the value [v] on [ppf]. Raises {!Error} in case of error. *)

    type 'a dec = string -> start:int -> int * 'a
    (** The type for textual decoders. [dec s ~start] textually
        decodes a value at [start] in [s]. [start] is either the first
        textual input bytes to consider (which may be whitespace or a
        commenet) or the length of [s]. The function returns [(i, v)]
        with [v] the decoded value and [i] the first index after the
        decoded value or the lenght of [s] if there is no such
        index. Raises {!Error} in case of error.

        {b XXX.} In the end this signature is showing its limits for
        error reporting.  Maybe we should have an abstraction here. *)

    (** {1:enc Encoding} *)

    val enc_err :
      kind:string -> ('a, Format.formatter, unit, 'b) format4 -> 'a
    (** [enc_err ~kind fmt] raises a textual encoding error message for kind
        [kind] formatted according to [fmt]. *)

    val enc_atom : string enc
    (** [enc_atom ppf s] encodes [s] as an {{!atom}atom} on [ppf] quoting
        it as needed. *)

    val enc_list : 'a enc -> 'a list enc
    (** [enc_list enc_v] encodes a list of values encoded with [enc_v]. *)

    (** {1:dec Decoding} *)

    type lexeme = [`Ls | `Le | `Atom of string]
    (** The type for s-expressions lexemes. *)

    val dec_err :
      kind:string -> int -> ('a, Format.formatter, unit, 'b) format4 -> 'a
    (** [dec_err ~kind i fmt] raises a textual decoding error message for
        kind [kind] at input byte index [i] formatted according to [fmt]. *)

    val dec_err_eoi : kind:string -> int -> 'a
    (** [dec_err_eoi ~kind i] raises a textual error message for kind [kind]
        at input byte index [i] indicating an unexpected end of input. *)

    val dec_err_lexeme :
      kind:string -> int -> lexeme -> exp:lexeme list -> 'a
    (** [dec_err_case ~kind i] raises a textual error message for kind
        [kind] at input byte index [i] indicating one of [exp] was
        expected. *)

    val dec_err_atom : kind:string -> int -> string -> exp:string list -> 'a
    (** [dec_err_atom ~kind i a exp] raises a textual error message for kind
        [kind] at input byte index [i] and atom [a] indicating one of [exp]
        atoms was expected. *)

    val dec_skip : kind:string -> string -> start:int -> int
    (** [dec_skip ~kind s ~start] starting at [start] (which can be
        out of bounds) is the first non-white, non-comment, byte index
        or the length of [s] if there is no such index. *)

    val dec_lexeme : kind:string -> (int * lexeme) dec
    (** [dec_case ~kind s ~start] starting at [start] (which can be
        out of bounds), skips whitespace and comment, looks for either
        a left parenthesis, right parenthesis or an atom and returns
        the index of their first position. Errors if end of input is
        is found. *)

    val dec_ls : kind:string -> string -> start:int -> int
    (** [dec_ls ~kind s ~start] starting at [start] (which can
        be out of bounds), skips whitespace and comments,
        parses a list start and returns the index after it
        or the length of [s]. *)

    val dec_le : kind:string -> string -> start:int -> int
    (** [dec_le ~kind s ~start] starting at [start] (which can be
        out of bounds), skips whitespace and comments, parses a list end
        and returns the index after it or the length of [s]. *)

    val dec_atom : kind:string -> string dec
    (** [dec_atom ~kind s ~start] starting at [start] (which can
        be out of bounds), skips whitespace and comments, parses
        an atom and returns the index after it or the length of
        [s]. *)

    val dec_list : 'a dec -> kind:string -> 'a list dec
    (** [dec_list dec_v ~kind] decodes a list of values decoded with
        [dec_v] for the given [kind]. *)

    val dec_list_tail : 'a dec -> kind:string -> ls:int -> 'a list dec
    (** [dec_list_tail dec_v ~kind ~lstart] decodes list elements
        decoded with [dec_v] and an the end of list for the given
        [kind], [ls] is the position of the list start. *)
  end

  (** {1:converters Converters} *)

  type 'a t
  (** The type for converters. *)

  val v :
    kind:string -> docvar:string -> 'a Bin.enc -> 'a Bin.dec -> 'a Txt.enc ->
    'a Txt.dec -> 'a t
  (** [v ~kind ~docvar bin_enc bin_dec txt_enc txt_dec] is a value
      converter using [bin_enc], [bin_dec], [txt_enc], [txt_dec] for
      binary and textual conversions. [kind] documents the kind of
      converted value and [docvar] a meta-variable used in
      documentation to stand for these values (use uppercase
      e.g. [INT] for integers). *)

  val kind : 'a t -> string
  (** [kind c] is the documented kind of value converted by [c]. *)

  val docvar  : 'a t -> string
  (** [docvar c] is the documentation meta-variable for values converted
      by [c]. *)

  val bin_enc : 'a t -> 'a Bin.enc
  (** [bin_enc c] is the binary encoder of [c]. *)

  val bin_dec : 'a t -> 'a Bin.dec
  (** [bin_dec c] is the binary decoder of [c]. *)

  val txt_enc : 'a t -> 'a Txt.enc
  (** [txt_enc c] is the textual encoder of [c]. *)

  val txt_dec : 'a t -> 'a Txt.dec
  (** [txt_dec c] is the textual decoder of [c]. *)

  val with_kind : ?docvar:string -> string -> 'a t -> 'a t
  (** [with_kind ~docvar k c] is [c] with kind [k] and documentation
      meta-variable [docvar] (defaults to [docvar c]). *)

  val with_docvar : string -> 'a t -> 'a t
  (** [with_docvar docvar c] is [c] with documentation meta-variable
      [docvar]. *)

  val with_conv :
    kind:string -> docvar:string -> ('b -> 'a) -> ('a -> 'b) -> 'a t -> 'b t
  (** [with_conv ~kind ~docvar to_t of_t t_conv] is a converter for type
      ['b] given a converter [t_conv] for type ['a] and conversion
      functions from and to type ['b]. The conversion functions should
      raise {!Error} if they are not total. *)

  (** {1:converting Converting} *)

  val to_bin : ?buf:Buffer.t -> 'a t -> 'a -> (string, string) result
  (** [to_bin c v] binary encodes [v] using [c]. [buf] is used as
      the internal buffer if specified (it is {!Buffer.clear}ed before
      usage). *)

  val of_bin : 'a t -> string -> ('a, string) result
  (** [of_bin c s] binary decodes a value from [s] using [c]. *)

  val to_txt : ?buf:Buffer.t -> 'a t -> 'a -> (string, string) result
  (** [to_txt c v] textually encodes [v] using [c]. [buf] is used as
      the internal buffer if specified (it is {!Buffer.clear}ed before
      usage). *)

  val of_txt : 'a t -> string -> ('a, string) result
  (** [of_txt c s] textually decodes a value from [s] using [c]. *)

  val to_pp : 'a t -> 'a Fmt.t
  (** [to_pp c] is a formatter using {!to_txt} to format values. Any
      error that might occur is printed in the output using
      the s-expression ({e conv-error} \[[c]\]{_kind} \[[e]\]) with
      \[[c]\]{_kind} the atom for the value [kind c] and \[[e]\]
      the atom for the error message. *)

  (** {1:predef Predefined converters} *)

  val bool : bool t
  (** [bool] converts booleans. Textual conversions represent booleans
      with the {{!atoms}atoms} {e true} and {e false}. *)

  val byte : int t
  (** [byte] converts a byte. Textual decoding parses an {{!atoms}atom}
      according to the syntax of {!int_of_string}. Conversions fail if
      the integer is not in the range \[0;255\].  *)

  val int : int t
  (** [int] converts signed OCaml integers. Textual decoding parses an
      {{!atoms}atom} according to the syntax of
      {!int_of_string}. Conversions fail if the integer is not in the
      range \[-2{^{!Sys.int_size}-1};2{^{!Sys.int_size}-1}-1\].

      {b Warning.} A large integer encoded on a 64-bit platform may
      fail to decode on a 32-bit platform, use {!int31} or {!int64} if
      this is a problem. *)

  val int31 : int t
  (** [int31] converts signed 31-bit integers. Textual decoding parses
      an {{!atoms}atom} according to the syntax of
      {!int_of_string}. Conversions fail if the integer is not in the
      range \[-2{^30};2{^30}-1\]. *)

  val int32 : int32 t
  (** [int32] converts signed 32-bit integers. Textual decoding parses
      an {{!atoms}atom} according to the syntax of
      {!Int32.of_string}. Conversions fail if the integer is not in
      the range \[-2{^31};2{^31}-1\]. *)

  val int64 : int64 t
  (** [int64] converts signed 64-bit integers. Textual decoding parses
      an {{!atoms}atom} according to the syntax of
      {!Int64.of_string}. Conversions fail if the integer is not in
      the range \[-2{^63};2{^63}-1\]. *)

  val float : float t
  (** [float] converts floating point numbers. Textual decoding parses
      an {{!atoms}atom} using {!float_of_string}. *)

  val string_bytes : string t
  (** [string_bytes] converts OCaml strings as byte sequences.
      Textual conversion represents the bytes of [s] with the
      s-expression ({e hex} \[[s]\]{_hex}) with \[[s]\]{_hex} the
      {{!atoms}atom} resulting from {!String.Ascii.to_hex}[ s].
      See also {!atom} and {!only_string}.

      {b Warning.} A large string encoded on a 64-bit platform may
      fail to decode on a 32-bit platform. *)

  val atom : string t
  (** [atom] converts strings assumed to represent UTF-8 encoded
      Unicode text; but the encoding is not checked. Textual
      conversions represent strings as {{!atoms}atoms}. See also
      {!string_bytes} and {!only_string}.

      {b Warning.} A large atom encoded on a 64-bit platform may fail
      to decode on a 32-bit platform. *)

  val atom_non_empty : string t
  (** [atom_non_empty] is like {!atom} but ensures the atom is
      not empty. *)

  val option : ?kind:string -> ?docvar:string -> 'a t -> 'a option t
  (** [option c] converts optional values converted with [c]. Textual
      conversions represent [None] with the {{!atoms}atom} {e none}
      and [Some v] with the s-expression ({e some} \[[v]\]{_c}). *)

  val some : 'a t -> 'a option t
  (** [some c] wraps decodes of [c] with {!Option.some}. {b Warning.}
      [None] can't be converted in either direction, use {!option} for
      this. *)

  val result : ?kind:string -> ?docvar:string -> 'a t -> 'b t ->
    ('a, 'b) result t
  (** [result ok error] converts result values with [ok] and [error].
      Textual conversions represent [Ok v] with the s-expression
      ({e ok} \[[v]\]{_ok}) and [Error e] with
      ({e error} \[[e]\]{_error}). *)

  val list : ?kind:string -> ?docvar:string -> 'a t -> 'a list t
  (** [array c] converts a list of values converted with [c]. Textual
      conversions represent a list [[v0; ... vn]] by the s-expression
      (\[[v0]\]{_c} ... \[[vn]\]{_c}).

      {b Warning.} A large list encoded on a 64-bit platform may fail
      to decode on a 32-bit platform. *)

  val array : ?kind:string -> ?docvar:string -> 'a t -> 'a array t
  (** [array c] is like {!list} but converts arrays.

      {b Warning.} A large array encoded on a 64-bit platform may fail
      to decode on a 32-bit platform. *)

  val pair : ?kind:string -> ?docvar:string -> 'a t -> 'b t -> ('a * 'b) t
  (** [pair c0 c1] converts pairs of values converted with [c0] and [c1].
      Textual conversion represent a pair [(v0, v1)] by the
      s-expression (\[[v0]\]{_c0} \[[v1]\]{_c1}). *)

  val enum :
    kind:string -> docvar:string -> ?eq:('a -> 'a -> bool) ->
    (string * 'a) list -> 'a t
  (** [enum ~kind ~docvar ~eq vs] converts values present in [vs].
      {!eq} is used to test equality among values (defaults to {!( =
      )}). The list length should not exceed 256. Textual conversions
      use the strings of the pairs in [vs] as {{!atoms}atoms} to
      encode the corresponding value. *)

  (** {1:non_composable Non-composable predefined converters}

      Textual conversions performed by the following converters cannot
      be composed; they do not respect the syntax of s-expression
      {{!atom}atoms}. They can be used for direct conversions when one
      does not want to be subject to the syntactic constraints of
      s-expressions. For example when parsing command line interface
      arguments or environment variables. *)

  val string_only : string t
  (** [string_only] converts OCaml strings. Textual conversion is
      {b not composable}, use {!string_bytes} or {!atom}
      instead. Textual encoding passes the string as is and decoding
      ignores the initial starting point and returns the whole input
      string.

      {b Warning.} A large string encoded on a 64-bit platform may
      fail to decode on a 32-bit platform. *)

  (** {1:sexp_syntax S-expressions syntax}

      S-expressions are a general way of describing data via atoms
      (sequences of characters) and lists delimited by parentheses.
      Here are a few examples of s-expressions and their syntax:
{v

this-is-an-atom
(this is a list of seven atoms)
(this list contains (a nested) list)

; This is a comment
; Anything that follows a semi-colon is ignored until the next line

(this list ; has three atoms and an embededded ()
 comment)

"this is a quoted atom, it can contain spaces ; and ()"

"quoted atoms can be split ^
 across lines or contain Unicode esc^u\{0061\}pes"
v}

      We define the syntax of s-expressions over a sequence of
      {{:http://unicode.org/glossary/#unicode_scalar_value}Unicode
      characters} in which all US-ASCII {{!Char.Ascii.is_control}control
      characters} except {{!whitespace}whitespace} are forbidden in
      unescaped form.

      {b Note.} This module assumes the sequence of Unicode characters
      is encoded as UTF-8 although it doesn't check this for now.

      {2:sexp S-expressions and sequences thereof}

      An {e s-expression} is either an {{!atoms}{e atom}} or a
      {{!lists}{e list}} of s-expressions interspaced with
      {{!whitespace}{e whitespace}} and {{!comments}{e comments}}. A {e
      sequence of s-expressions} is a succession of s-expressions
      interspaced with whitespace and comments.

      These elements are informally described below and finally made
      precise via an ABNF {{!grammar}grammar}.

      {2:whitespace Whitespace}

      Whitespace is a sequence of whitespace characters, namely, space
      [' '] (U+0020), tab ['\t'] (U+0009), line feed ['\n'] (U+000A),
      vertical tab ['\t'] (U+000B), form feed (U+000C) and carriage return
      ['\r'] (U+000D).

      {2:comments Comments}

      Unless it occurs inside an atom in quoted form (see below)
      anything that follows a semicolon [';'] (U+003B) is ignored until
      the next {e end of line}, that is either a line feed ['\n'] (U+000A), a
      carriage return ['\r']  (U+000D) or a carriage return and a line feed
      ["\r\n"] (<U+000D,U+000A>).
{v
(this is not a comment) ; This is a comment
(this is not a comment)
v}

      {2:atoms Atoms}

      An atom represents ground data as a string of Unicode characters.
      It can, via escapes, represent any sequence of Unicode characters,
      including control characters and U+0000. It cannot represent an
      arbitrary byte sequence except via a client-defined encoding
      convention (e.g. Base64 or {{!string_bytes}hex encoding}).

      Atoms can be specified either via an unquoted or a quoted form. In
      unquoted form the atom is written without delimiters. In quoted
      form the atom is delimited by double quote ['\"'] (U+0022) characters,
      it is mandatory for atoms that contain {{!whitespace}whitespace},
      parentheses ['('] [')'], semicolons [';'], quotes ['\"'], carets ['^']
      or characters that need to be escaped.
{v
abc        ; a token for the atom "abc"
"abc"      ; a quoted token for the atom "abc"
"abc; (d"  ; a quoted token for the atom "abc; (d"
""         ; the quoted token for the atom ""
v}
      For atoms that do not need to be quoted, both their unquoted and
      quoted form represent the same string; e.g. the string ["true"]
      can be represented both by the atoms {e true} and {e
      "true"}. The empty string can only be represented in quoted form
      by {e ""}.

      In quoted form escapes are introduced by a caret ['^']. Double
      quotes ['\"'] and carets ['^'] must always be escaped.
{v
"^^"             ; atom for ^
"^n"             ; atom for line feed U+000A
"^u\{0000\}"       ; atom for U+0000
"^"^u\{1F42B\}^""  ; atom with a quote, U+1F42B and a quote
v}
      The following escape sequences are recognized:
      {ul
      {- ["^ "] (<U+005E,U+0020>) for space [' '] (U+0020)}
      {- ["^\""] (<U+005E,U+0022>) for double quote ['\"'] (U+0022)
         {b mandatory}}
      {- ["^^"] (<U+005E,U+005E>) for caret ['^'] (U+005E) {b mandatory}}
      {- ["^n"] (<U+005E,U+006E>) for line feed ['\n'] (U+000A)}
      {- ["^r"] (<U+005E,U+0072>) for carriage return ['\r'] (U+000D)}
      {- ["^u{X}"] with [X] is from 1 to at most 6 upper or lower case
         hexadecimal digits standing for the corresponding
         {{:http://unicode.org/glossary/#unicode_scalar_value}Unicode character}
         U+X.}
      {- Any other character except line feed ['\n'] (U+000A) or
         carriage return ['\r'] (U+000D), following a caret is an
         illegal sequence of characters. In the two former cases the
         atom continues on the next line and white space is ignored.}}
      An atom in quoted form can be split across lines by using a caret
      ['^'] (U+005E) followed by a line feed ['\n'] (U+000A) or a
      carriage return ['\r'] (U+000D); any subsequent
      {{!whitespace}whitespace} is ignored.
{v
"^
  a^
  ^ " ; the atom "a "
v}
      The character ['^'] (U+005E) is used as an escape character rather
      than the usual ['\\'] (U+005C) in order to make quoted Windows®
      file paths decently readable and, not the least, utterly please DKM.

      {2:lists Lists}

      Lists are delimited by left ['('] (U+0028) and right
      [')'] (U+0029) parentheses. Their elements are s-expressions separated by
      optional {{!whitespace}whitespace} and {{!comments}comments}. For example:
{v
(a list (of four) expressions)
(a list(of four)expressions)
("a"list("of"four)expressions)
(a list (of ; This is a comment
four) expressions)
() ; the empty list
v}

      {2:grammar S-expression grammar}

      The following {{:https://tools.ietf.org/html/rfc5234}RFC 5234}
      ABNF grammar is defined on a sequence of
      {{:http://unicode.org/glossary/#unicode_scalar_value}Unicode characters}.
{v
 sexp-seq = *(ws / comment / sexp)
     sexp = atom / list
     list = %x0028 sexp-seq %x0029
     atom = token / qtoken
    token = t-char *(t-char)
   qtoken = %x0022 *(q-char / escape / cont) %x0022
   escape = %x005E (%x0020 / %x0022 / %x005E / %x006E / %x0072 /
                    %x0075 %x007B unum %x007D)
     unum = 1*6(HEXDIG)
     cont = %x005E nl ws
       ws = *(ws-char)
  comment = %x003B *(c-char) nl
       nl = %x000A / %x000D / %x000D %x000A
   t-char = %x0021 / %x0023-0027 / %x002A-%x003A / %x003C-%x005D /
            %x005F-%x007E / %x0080-D7FF / %xE000-10FFFF
   q-char = t-char / ws-char / %x0028 / %x0029 / %x003B
  ws-char = %x0020 / %x0009 / %x000A / %x000B / %x000C / %x000D
   c-char = %x0009 / %x000B / %x000C / %x0020-D7FF / %xE000-10FFFF
v}
      A few additional constraints not expressed by the grammar:
      {ul
      {- [unum] once interpreted as an hexadecimal number must be a
       {{:http://unicode.org/glossary/#unicode_scalar_value}Unicode scalar
       value.}}
      {- A comment can be ended by the end of the character sequence rather
       than [nl]. }} *)
end

(** File paths.

    A file system {e path} specifies a file or a directory in a file
    system hierarchy. It is made of three parts:

    {ol
    {- An optional, platform-dependent, volume.}
    {- An optional root directory separator {!dir_sep} whose presence
       distiguishes absolute paths (["/a"]) from {e relative} ones
       (["a"])}
    {- A non-empty list of {!dir_sep} separated segments. {e Segments}
       are non empty strings except for maybe the last one. The latter
       syntactically distiguishes {e directory paths} (["a/b/"]) from
       file paths (["a/b"]).}}

    The paths segments ["."] and [".."] are relative path segments
    that respectively denote the current and parent directory. The
    {{!basename}basename} of a path is its last non-empty segment if
    it is not a relative path segment or the empty string otherwise (e.g.
    on ["/"]). *)
module Fpath : sig

  (** {1:segments Separators and segments} *)

  val dir_sep_char : char
  (** [dir_sep_char] is the platform dependent natural directory
      separator.  This is / on POSIX and \ on Windows. *)

  val dir_sep : string
  (** [dir_sep] is {!dir_sep_char} as a string. *)

  val is_seg : string -> bool
  (** [is_seg s] is [true] iff [s] does not contain a {!dir_sep} or
      a null byte. *)

  val is_rel_seg : string -> bool
  (** [is_rel_seg s] is [true] iff [s] is a relative segment in other
      words either ["."] or [".."]. *)

  (** {1:paths Paths} *)

  type t
  (** The type for paths *)

  val v : string -> t
  (** [v s] is the string [s] as a path.

      {b Warning.} In code only use ["/"] as the directory separator
      even on Windows platforms (don't be upset, the module gives them
      back to you with backslashes).

      @raise Invalid_argument if [s] is not a {{!of_string}valid
      path}. Use {!of_string} to deal with untrusted input. *)

  val add_seg : t -> string -> t
  (** [add_seg p seg] if [p]'s last segment is non-empty this is
      [p] with [seg] added. If [p]'s last segment is empty, this is
      [p] with the empty segment replaced by [seg].

      @raise Invalid_argument if [is_seg seg] is [false]. *)

  val append : t -> t -> t
  (** [append p q] appends [q] to [p] as follows:
      {ul
      {- [q] is absolute or has a non-empty volume then [q] is returned.}
      {- Otherwise appends [q]'s segment to [p] using {!add_seg}.}} *)

  val ( / ) : t -> string -> t
  (** [p / seg] is [add_seg p seg]. Left associative. *)

  val ( // ) : t -> t -> t
  (** [p // p'] is [append p p']. Left associative. *)

  (** {1:dirpaths Directory paths}

      {b Note.} The following functions use syntactic semantic
      properties of paths. Given a path, these properties can be
      different from the ones your file system attributes to it. *)

  val is_dir_path : t -> bool
  (** [is_dir_path p] is [true] iff [p] syntactically represents
      a directory. This means that [p] is [.], [..] or ends
      with [/], [/.] or [/..]. *)

  val to_dir_path : t -> t
  (** [to_dir_path p] is [add_seg p ""]. It ensures that the resulting
      path represents a {{!is_dir_path}directory} and, if converted
      to a string, that it ends with a {!dir_sep}. *)

  (** {1:baseparent Basename and parent directory}

      {b Note.} The following functions use syntactic semantic
      properties of paths. Given a path, these properties can be
      different from the ones your file system attributes to it. *)

  val basename : t -> string
  (** [basename p] is the last non-empty segment of [p] or the empty
      string otherwise. The latter occurs only on root paths and on
      paths whose last non-empty segment is a relative segment. *)

  val parent : t -> t
  (** [parent p] is a {{!is_dir_path}directory path} that contains
      [p]. If [p] is a {{!is_root}root path} this is [p] itself.
      If [p] is in the current directory this is [./]. *)

  (** {1:preds Predicates and comparison} *)

  val is_rel : t -> bool
  (** [is_rel p] is [true] iff [p] is a relative path, i.e. the root
      directory separator is missing in [p]. *)

  val is_abs : t -> bool
  (** [is_abs p] is [true] iff [p] is an absolute path, i.e. the root
      directory separator is present in [p]. *)

  val is_root : t -> bool
  (** [is_root p] is [true] iff [p] is a root directory, i.e. [p] has
      the root directory separator and a single, empty, segment. *)

  val is_current_dir : t -> bool
  (** [is_current_dir p] is [true] iff [p] is either ["."] or ["./"]. *)

  val is_parent_dir : t -> bool
  (** [is_parent_dir p] is [true] iff [p] is either [".."] or ["../"]. *)

  val equal : t -> t -> bool
  (** [equal p0 p1] is true iff [p0] and [p1] are stringwise equal. *)

  val equal_basename : t -> t -> bool
  (** [equal_basename p0 p1] is [String.equal (basename p0) (basename p1)]. *)

  val compare : t -> t -> int
  (** [compare p0 p1] is a total order on paths compatible with {!equal}. *)

  (** {1:file_exts File extensions}

      The {e file extension} (resp. {e multiple file extension}) of a
      path segment is the suffix that starts at the last (resp. first)
      occurence of a ['.'] that is preceeded by at least one non ['.']
      character.  If there is no such occurence in the segment, the
      extension is empty.  With these definitions, ["."], [".."],
      ["..."] and dot files like [".ocamlinit"] or ["..ocamlinit"] have
      no extension, but [".emacs.d"] and ["..emacs.d"] do have one. *)

  type ext = string
  (** The type for file extensions, ['.'] separator included.  *)

  val get_ext : ?multi:bool -> t -> ext
  (** [get_ext p] is [p]'s {{!basename}basename} file extension or the empty
      string if there is no extension. If [multi] is [true] (defaults to
      [false]), returns the multiple file extension. *)

  val has_ext : ext -> t -> bool
  (** [has_ext ext p] is [true] iff
      [String.equal (get_ext p) e || String.equal (get_ext ~multi:true p) e]. *)

  val mem_ext : ext list -> t -> bool
  (** [mem_ext exts p] is [List.exists (fun e -> has_ext e p) exts] *)

  val add_ext : ext -> t -> t
  (** [add_ext ext p] is [p] with [ext] concatenated to [p]'s
      {{!basename}basename}. *)

  val rem_ext : ?multi:bool -> t -> t
  (** [rem_ext ?multi p] is [p] with the extension of [p]'s
      {{!basename}basename} removed. If [multi] is [true] (defaults to
      [false]), the multiple file extension is removed. *)

  val set_ext : ?multi:bool -> ext -> t -> t
  (** [set_ext ?multi p] is [add_ext ext (rem_ext ?multi p)]. *)

  val cut_ext : ?multi:bool -> t -> t * ext
  (** [cut_ext ?multi p] is [(rem_ext ?multi p, get_ext ?multi p)]. *)

  val ( + ) : t -> ext -> t
  (** [p + ext] is [add_ext p ext]. Left associative. *)

  val ( -+ ) : t -> ext -> t
  (** [p -+ ext] is [set_ext p ext]. Left associative. *)

  (** {1:converting Converting} *)

  val of_string : string -> (t, string) result
  (** [of_string s] is the string [s] as a path. The following transformations
      are performed on the string:
      {ul
      {- On Windows any / ([0x2F]) occurence is converted to \ ([0x5C])}}
      An error returned if [s] is [""] or if it contains a null byte. The
      error string mentions [s]. *)

  val to_string : t -> string
  (** [to_string p] is the path [p] as a string. The result can
      be safely converted back with {!v}. *)

  val conv : t Conv.t
  (** [conv] converts file paths. The textual representation
      uses non-empty {{!Conv.atoms}atoms}. See also {!conv_only}. *)

  val conv_only : t Conv.t
  (** [conv_only] converts file paths. Textual conversion is {b not
      composable}, use {!conv} instead. Textual encoding pass the
      string as is and decoding ignores the initial starting point and
      parses the whole input string into a file path. *)

  val pp : t Fmt.t
  (** [pp ppf p] prints path [p] on [ppf] using {!to_string}. *)

  val pp_quoted : t Fmt.t
  (** [pp_quoted p] prints path [p] on [ppf] using {!Filename.quote}. *)

  val dump : t Fmt.t
  (** [dump ppf p] prints path [p] on [ppf] using {!String.dump}. *)

  (** {1:unique Uniqueness} *)

  val uniquify : t list -> t list
  (** [uniquify ps] is [ps] without duplicates, the list order is
      preserved. *)

  (** {1:setmap Paths map and sets} *)

  type path = t

  (** Path sets. *)
  module Set : sig

    (** {1 Path sets} *)

    include Set.S with type elt := t

    val pp : ?sep:unit Fmt.t -> path Fmt.t -> t Fmt.t
    (** [pp ~sep pp_elt ppf ss] formats the elements of [ss] on
        [ppf]. Each element is formatted with [pp_elt] and elements
        are separated by [~sep] (defaults to
        {!Format.pp_print_cut}). If the set is empty leaves [ppf]
        untouched. *)

    val dump : t Fmt.t
    (** [dump ppf ss] prints an unspecified representation of [ss] on
        [ppf]. *)
  end

  (** Path maps. *)
  module Map : sig

    (** {1 Path maps} *)

    include Map.S with type key := t

    val dom : 'a t -> Set.t
    (** [dom m] is the domain of [m]. *)

    val of_list : (path * 'a) list -> 'a t
    (** [of_list bs] is [List.fold_left (fun m (k, v) -> add k v m) empty
        bs]. *)

    val pp : ?sep:unit Fmt.t -> (path * 'a) Fmt.t -> 'a t Fmt.t
    (** [pp ~sep pp_binding ppf m] formats the bindings of [m] on
        [ppf]. Each binding is formatted with [pp_binding] and
        bindings are separated by [sep] (defaults to
        {!Format.pp_print_cut}). If the map is empty leaves [ppf]
        untouched. *)

    val dump : 'a Fmt.t -> 'a t Fmt.t
    (** [dump pp_v ppf m] prints an unspecified representation of [m] on
        [ppf] using [pp_v] to print the map codomain elements. *)
  end

  (** {1:sp Search paths}

      A {e search path} is a list of paths separated by a designated
      separator. A well known search path is [PATH] in which executable
      binaries are looked up. *)

  val search_path_sep : string
  (** [search_path_sep] is the default platform specific separator for
      search paths, this is [";"] if {!Sys.win32} is [true] and [":"]
      otherwise. *)

  val list_of_search_path : ?sep:string -> string -> (t list, string) result
  (** [list_of_search_path ~sep s] parses [sep] separated file paths
      from [s]. [sep] is not allowed to appear in the file paths, it
      defaults to {!search_path_sep}. The order in the list
      matches the order from left to right in [s]. *)
end

(** Hash values and functions.

    The property we want from these functions is speed and collision
    resistance. Build correctness depends on the latter. *)
module Hash : sig

  (** {1:values Hash values} *)

  type t
  (** The type for hash values. All hash functions use this representation.
      It is not possible to distinguish them, except for their {!length}
      which might vary, or not. *)

  val nil : t
  (** [nil] is the only hash value of {!length} [0]. *)

  val length : t -> int
  (** [length h] is the length of [h] in bytes. *)

  (** {1:preds Predicate and comparisons} *)

  val is_nil : t -> bool
  (** [is_nil h] is [true] iff [h] is {!nil}. *)

  val equal : t -> t -> bool
  (** [equal h0 h1] is [true] iff [h0] and [h1] are equal. *)

  val compare : t -> t -> int
  (** [compare h0 h1] is a total order on hashes compatible with {!equal}. *)

  (** {1:converting Converting} *)

  val to_bytes : t -> string
  (** [to_bytes h] is the sequence of bytes of [h]. *)

  val of_bytes : string -> t
  (** [of_bytes s] is the sequences of bytes of [s] as a hash value. *)

  val to_hex : t -> string
  (** [to_hex h] is {!String.Ascii.to_hex}[ (to_bytes h)]. *)

  val of_hex : string -> (t, int) result
  (** [of_hex s] is [Result.map of_bytes (]{!String.Ascii.of_hex}[ s)]. *)

  val conv : t Conv.t
  (** [conv] converts using {!Conv.string_bytes}. *)

  val pp : t Fmt.t
  (** [pp] formats using {!to_hex} or, if the hash is {!nil},
      formats ["nil"]. *)

  (** {1:funs Hash functions} *)

  (** The type for hash functions. *)
  module type T = sig

    (** {1:hash Hash function} *)

    val id : string
    (** [id] is an US-ASCII string identifying the hash function. *)

    val length : int
    (** [length] is the byte length of hashes produced by the function. *)

    val string : string -> t
    (** [string s] is the hash of [s]. *)

    val fd : Unix.file_descr -> t
    (** [fd fd] [mmap(2)]s and hashes the object pointed by [fd].
        @raise Sys_error if [mmap] fails. *)

    val file : Fpath.t -> (t, string) result
    (** [file f] is the hash of file [f]. *)
  end

  module Murmur3_128 : T
  (** [Murmur3_128] is the
      {{:https://github.com/aappleby/smhasher}MurmurHash3 128-bit} hash. *)

  module Xxh_64 : T
  (** [Xxh_64] is the {{:http://cyan4973.github.io/xxHash/}xxHash 64-bit}
      hash. *)

  val funs : unit -> (module T) list
  (** [funs ()] is the list of available hash functions. *)

  val add_fun : (module T) -> unit
  (** [add_fun m] adds [m] to the list returned by [funs]. *)
end

(** Measuring time.

    Support to measure monotonic wall-clock {{!monotonic}time}, CPU
    user and CPU system time. *)
module Time : sig

  (** {1:span Monotonic time spans} *)

  type span
  (** The type for non-negative monotonic time spans. They represent
      the difference between two clock readings with nanosecond precision
      (1e-9s). *)

  (** Time spans *)
  module Span : sig

    (** {1:span Time spans} *)

    type t = span
    (** See {!type:span}. *)

    val zero : span
    (** [zero] is a span of 0ns. *)

    val one : span
    (** [one] is a span of 1ns. *)

    val add : span -> span -> span
    (** [add s0 s1] is [s0] + [s1]. {b Warning.} Rolls over on overflow. *)

    val abs_diff : span -> span -> span
    (** [abs_diff s0 s1] is the absolute difference between [s0] and [s1]. *)

    (** {1:preds Predicates and comparisons} *)

    val equal : span -> span -> bool
    (** [equal s0 s1] is [s0 = s1]. *)

    val compare : span -> span -> int
    (** [compare s0 s1] orders span by increasing duration. *)

    (** {1:conv Conversions} *)

    val to_uint64_ns : span -> int64
    (** [to_uint64_ns s] is [s] as an {e unsigned} 64-bit integer nanosecond
        span. *)

    val of_uint64_ns : int64 -> span
    (** [of_uint64_ns u] is the {e unsigned} 64-bit integer nanosecond span [u]
        as a span. *)

    val conv : span Conv.t
    (** [conv] is a converter for timespans. Texual conversion parses
        an {{!atoms}atom} using {!Int64.of_string}. *)

    val pp : span Fmt.t
    (** [pp] formats with {!Fmt.uint64_ns_span}. *)

    val pp_ns : span Fmt.t
    (** [pp_ns ppf s] prints [s] as an unsigned 64-bit integer nanosecond
        span. *)
  end

  (** {1:monotonic_counters Monotonic wall-clock time counters} *)

  type counter
  (** The type for monotonic wall-clock time counters. *)

  val counter : unit -> counter
  (** [counter ()] is a counter counting from now on. *)

  val count : counter -> span
  (** [count c] is the monotonic time span elapsed since [c] was created. *)

  (** {1:cpu_span CPU time spans} *)

  type cpu_span
  (** The type for CPU execution time spans. *)

  val cpu_zero : cpu_span
  (** [cpu_zero] is zero CPU times. *)

  val cpu_utime : cpu_span -> span
  (** [cpu_utime_s cpu] is [cpu]'s user time in seconds. *)

  val cpu_stime : cpu_span -> span
  (** [cpu_stime_s cpu] is [cpu]'s system time in seconds. *)

  val cpu_children_utime : cpu_span -> span
  (** [cpu_utime_s cpu] is [cpu]'s user time in seconds for children
      processes. *)

  val cpu_children_stime : cpu_span -> span
  (** [cpu_utime_s cpu] is [cpu]'s system time in seconds for children
      processes. *)

  val cpu_span_conv : cpu_span Conv.t
  (** [cpu_span_conv] is a converter for cpu spans. *)

  (** {1:cpu_counter CPU time counters} *)

  type cpu_counter
  (** The type for CPU time counters. *)

  val cpu_counter : unit -> cpu_counter
  (** [cpu_counter ()] is a counter counting from now on. *)

  val cpu_count : cpu_counter -> cpu_span
  (** [cpu_count c] are CPU times since [c] was created. *)
end

(** Command lines.

    Command line values specify the command line arguments given to
    tools spawns. In certain contexts the command line value is the
    full specification of the tool spawn, in this case the first
    element of the line defines the program to invoke. In other
    contexts the tool to invoke and its arguments are kept separate.

    {!examples}.

    {b B0 artefact.}
    This module allows to {!shield} command arguments. Shielded
    arguments have no special semantics as far as the command line is
    concerned they simply indicate that the argument value itself does
    not influence the file outputs of the tool. As such shielded
    arguments do not appear in the command line
    {{!to_list_and_sig}signature} which is used to memoize tool
    spawns. A typical example of shielded argument are file paths to
    inputs: it's often the file contents not the actual file path that
    determines the tool output; beware though that some tool use both
    the file path contents and the actual file path in their outputs. *)
module Cmd : sig

  (** {1:cl Command lines} *)

  type t
  (** The type for command lines. A command line is a list of command
      line arguments. *)

  val is_empty : t -> bool
  (** [is_empty l] is [true] iff [l] is an empty list of arguments. *)

  val empty : t
  (** [empty] is an empty list of arguments. *)

  val arg : string -> t
  (** [arg a] is the argument [a]. *)

  val append : t -> t -> t
  (** [append l1 l2] appends arguments [l2] to [l1]. *)

  val shield : t -> t
  (** [shield l] indicates that arguments [l] do not influence the
      tool's invocation outputs. These arguments are omitted from
      the command line's {{!to_list_and_sig}signature}. *)

  (** {1:derived Derived combinators} *)

  val ( % ) : t -> string -> t
  (** [l % a] is [append l (arg a)]. *)

  val ( %% ) : t -> t -> t
  (** [l1 % l2] is [append l1 l2]. *)

  val if' : bool -> t -> t
  (** [if' cond l] is [l] if [cond] is [true] and {!empty} otherwise. *)

  val path : Fpath.t -> t
  (** [path p] is [arg (Fpath.to_string p)]. *)

  val spath : Fpath.t -> t
  (** [spath p] is [shield (path p)]. *)

  val args : ?slip:string -> string list -> t
  (** [args ?slip l] is a command line from the list of arguments [l].
      If [slip] is specified it is added on the command line before
      each element of [l]. *)

  val rev_args : ?slip:string -> string list -> t
  (** [rev_args ?slip l] is {!args}[ ?slip (List.rev l)]. *)

  val of_list : ?slip:string -> ('a -> string) -> 'a list -> t
  (** [of_list ?slip conv l] is {!args}[ ?slip (List.map conv l)]. *)

  val of_rev_list : ?slip:string -> ('a -> string) -> 'a list -> t
  (** [of_rev_list ?slip conv l] is {!args}[ ?slip (List.rev_map conv l)]. *)

  val paths : ?slip:string -> Fpath.t list -> t
  (** [paths ?slip ps] is {!of_list}[ ?slip Fpath.to_string ps]. *)

  val rev_paths : ?slip:string -> Fpath.t list -> t
  (** [rev_paths ?slip ps] is {!of_rev_list}[ ?slip Fpath.to_string ps]. *)

  (** {1:tool Tools} *)

  type tool = Fpath.t
  (** The type for command line tools. A command line tool is
      represented by a file path according to the POSIX convention for
      [exec(3)]. If it is made of a single segment, for example
      [Fpath.v "ocaml"], it represents a program name to be looked up
      via a search procedure; for example in the [PATH] environment
      variable. If it is a file path with multiple segments (POSIX
      would say if they contain a slash characters) the program is the
      file itself. *)

  val tool : t -> tool option
  (** [tool l] is [l]'s first element. This is [None] if the line is
      {!empty} or if the first element can't be parsed to a {!tool}. *)

  val set_tool : tool -> t -> t option
  (** [set_tool tool l] replaces [l]'s first element with [tool]. This
      is [None] if [l] is {!empty}. *)

  val get_tool : t -> tool
  (** [get_tool] is like {!tool} but @raise Invalid_argument in case
      of error. *)

  (** {1:preds Predicates} *)

  val is_singleton : t -> bool
  (** [is_singleton l] is [true] iff [l] has a single argument. *)

  (** {1:converting Converting} *)

  val to_list : t -> string list
  (** [to_list l] converts [l] to a list of strings. *)

  val to_sig : t -> string list
  (** [to_sig l] is the sequence of unshielded arguments. *)

  val to_list_and_sig : t -> string list * string list
  (** [to_list_and_sig l] is a [l] as a list of strings tuppled with
      its signature: the sequence of unshielded arguments. *)

  val to_string : t -> string
  (** [to_string l] converts [l] to a string that can be passed
      to the
      {{:http://pubs.opengroup.org/onlinepubs/9699919799/functions/system.html}
      [command(3)]} POSIX system call. *)

  val of_string : string -> (t, string) result
  (** [of_string s] tokenizes [s] into a command line. The tokens
      are recognized according to the [token] production of the following
      grammar which should be mostly be compatible with POSIX shell
      tokenization.
{v
white   ::= ' ' | '\t' | '\n' | '\x0B' | '\x0C' | '\r'
squot   ::= '\''
dquot   ::= '\"'
bslash  ::= '\\'
tokens  ::= white+ tokens | token tokens | ϵ
token   ::= ([^squot dquot white] | squoted | dquoted) token | ϵ
squoted ::= squot [^squot]* squot
dquoted ::= dquot (qchar | [^dquot])* dquot
qchar   ::= bslash (bslash | dquot | '$' | '`' | '\n')
v}
      [qchar] are substitued by the byte they escape except for ['\n']
      which removes the backslash and newline from the byte stream.
      [squoted] and [dquoted] represent the bytes they enclose. *)

  val conv : t Conv.t
  (** [conv] converts command lines. *)

  val pp : t Fmt.t
  (** [pp ppf l] formats an unspecified representation of [l] on
      [ppf]. *)

  val dump : t Fmt.t
  (** [dump ppf l] dumps and unspecified representation of [l]
      on [ppf]. *)

  (** {1:examples Examples}
{[
let ls p = Cmd.(arg "ls" % "-a" % path p)
let tar archive dir =
  Cmd.(arg "tar" % "-cvf" %% shield (path archive) %% path dir)

let opam cmd = Cmd.(arg "opam" % cmd)
let opam_install pkgs = Cmd.(opam "install" %% args pkgs)

let ocamlc ?(debug = false) file =
  Cmd.(arg "ocamlc" % "-c" % if' debug (arg "-g") %% path file)

let ocamlopt ?(profile = false) ?(debug = false) incs file =
  let profile = Cmd.(if' profile (arg "-p")) in
  let debug = Cmd.(if' debug (arg "-g")) in
  let incs = Cmd.(shield (paths ~slip:"-I" incs)) in
  Cmd.(arg "ocamlopt" % "-c" %% debug %% profile %% incs %% shield (path file))
]} *)
end

(** OS interaction. *)
module Os : sig

  (** Environment variables. *)
  module Env : sig

    (** {1:var Variables} *)

    val find : empty_to_none:bool -> string -> string option
    (** [find ~empty_to_none name] is the value of the environment
        variable [name] in the current process environment, if
        defined. If [empty_to_none] is [true] (default), [None] is
        returned if the variable value is the empty string. *)

    val find_value :
      (string -> ('a, string) result) -> empty_to_none:bool -> string ->
      ('a, string) result option
    (** [find_value parse ~empty_to_none name] is [Option.bind parse
        (find ~empty_to_none name)], except the error message of
        [parse] is tweaked to mention [name] in case of error. *)

    (** {1:env Process environement} *)

    type t = string String.Map.t
    (** The type for process environments. *)

    val empty : t
    (** [empty] is {!String.Map.empty}. *)

    val override : t -> by:t -> t
    (** [override env ~by:o] overrides the definitions in [env] by [o]. *)

    val current : unit -> (t, string) result
    (** [current ()] is the current process environment. *)

    (** {1:assign Process environments as assignments} *)

    type assignments = string list
    (** The type for environments as lists of strings of the form
        ["var=value"]. *)

    val current_assignments : unit -> (assignments, string) result
    (** [current_assignments ()] is the current process environment as
        assignments. *)

    val of_assignments : ?init:t -> string list -> (t, string) result
    (** [of_assignments ~init ss] folds over strings in [ss],
        {{!String.cut}cuts} them at the leftmost ['='] character and
        adds the resulting pair to [init] (defaults to {!empty}). If
        the same variable is bound more than once, the last one takes
        over. *)

    val to_assignments : t -> assignments
    (** [to_assignments env] is [env]'s bindings as assignments. *)
  end

  (** File system path operations.

      These functions operate on files and directories
      equally. Specific function operating on either kind of path are
      in the {!File} and {!Dir} modules. *)
  module Path : sig

    (** {1:existence Existence} *)

    val exists : Fpath.t -> (bool, string) result
    (** [exists p] is [Ok true] if [p] exists in the file system
        and [Ok false] otherwise. Symbolic links are followed. *)

    val must_exist : Fpath.t -> (unit, string) result
    (** [must_exist p] is [Ok ()] if [p] exists in the file system
        and an error otherwise. Symbolic links are followed. *)

    (** {1:renaming Deleting and renaming} *)

    val delete : recurse:bool -> Fpath.t -> (bool, string) result
    (** [delete ~recurse p] deletes [p] from the file system. If [p]
        is a symbolic link this only deletes the link, not the linked
        object. If [recurse] is [true] and [p] is a non-empty
        directory, no error occurs, its contents is recursively
        deleted.  The result is:
        {ul
        {- [Ok true], if [p] existed and was deleted.}
        {- [Ok false], if the path [p] did not exist on the file system.}
        {- [Error _ ] in case of error, in particular if [p] is a non-empty
           directory and [recurse] is [false].}}
        See also {!File.delete}. *)

    val rename :
      force:bool -> make_path:bool -> src:Fpath.t -> Fpath.t ->
      (unit, string) result
    (** [rename ~force ~make_path ~src dst] renames [src] to [dst].
        {ul
        {- If [force] is [true] and [dst] exists it tries to delete it
           using {!File.delete}[ dst]. If [force] is [false]
           and [dst] exists the function errors.}
        {- If [make_path] is [true] and the parent directory of [dst] does
           not exist the whole path to the parent is created as needed
           with permission [0o755] (readable and traversable by everyone,
           writable by the user).}} *)

    (** {1:copy Copying} *)

    val copy :
      ?rel:bool -> ?atomic:bool -> ?allow_hardlinks:bool ->
      ?follow_symlinks:bool ->
      ?prune:(Unix.stats -> string -> Fpath.t -> bool) -> make_path:bool ->
      recurse:bool -> src:Fpath.t -> Fpath.t -> (unit, string) result
    (** [copy ~make_path ~recurse ~src dst] copies the file or file
        hierarchy rooted at [src] to [dst]. The function errors if
        [dst] exists. The semantics and arguments correspond to those
        of {!Os.Dir.copy}, except this function also works if [src] is
        not a directory. Note that [prune] is never called on [src]
        itself {b FIXME is that a good idea ?} also {b FIXME} this should
        error if [src] is a directory and [recurse] is false.

        See also {!Os.Dir.copy} and {!Os.File.copy}. *)

    (** {1:stat_mode File mode and stat}

        See also {!File.is_executable}. *)

    val get_mode : Fpath.t -> (int, string) result
    (** [get_mode p] is the file mode of [p]. Symbolic links are followed. *)

    val set_mode : Fpath.t -> int -> (unit, string) result
    (** [set_mode file p] sets the file mode of [file] to [p]. Symbolic
        links are followed. *)

    val stat : Fpath.t -> (Unix.stats, string) result
    (** [stat p] is [p]'s file information. Symbolic links are followed. *)

    (** {1:symlinks Symbolic links}

        For hard links see {!File.hard_links}. *)

    val symlink :
      force:bool -> make_path:bool -> src:Fpath.t -> Fpath.t ->
      (unit, string) result
    (** [symlink ~force ~src p] symbolically links [src] to [p].
        {ul
        {- If [force] is [true] and [p] exists it tries to delete it
           using {!File.delete}[ p]. If [force] is [false]
           and [p] exists the function errors.}
        {- If [make_path] is [true] and the parent directory of [file] does
           not exist the whole path to the parent is created as needed
           with permission [0o755] (readable and traversable by everyone,
           writable by the user).}} *)

    val symlink_link : Fpath.t -> (Fpath.t, string) result
    (** [symlink_link p] is [Ok l] if [p] is a symbolic link to [l]. *)

    val symlink_stat : Fpath.t -> (Unix.stats, string) result
    (** [symlink_stat p] is like {!stat} but if [p] is a symlink returns
        information about the link itself. If [p] is not a symlink then
        this is {!stat}. *)

    (** {1:tmppaths Temporary paths} *)

    type tmp_name = (string -> string, unit, string) format
    (** The type for temporary file name patterns. The string format
        is replaced by random hexadecimal US-ASCII characters. *)

    val tmp :
      ?make_path:bool -> ?dir:Fpath.t -> ?name:tmp_name -> unit ->
      (Fpath.t, string) result
    (** [tmp ~make_path ~dir name ()] is a file system path in [dir] that
        did not exist when the name was found. It may exist once the function
        returns though, prefer temporary {{!File.tmpfiles}files} and
        {{!Dir.tmpdirs}directories} creation functions to guarantee the
        creation of the temporary objects.
        {ul
        {- [name] is used to construct the filename of the file,
           see {!type:tmp_name} for details. It defaults to ["tmp-%s"].}
        {- [dir] is the directory in which the temporary file is created.
           It defaults to {!Os.Dir.default_tmp}[ ()].}
        {- If [make_path] is [true] (default) and [dir] does not exist the
           whole path to it is created as needed with permission [0o755]
           (readable and traversable by everyone, writable by the user).}} *)
  end

  (** Regular file operations.

      This module operates on regular files, most functions error if
      they are applied to other file kinds. *)
  module File : sig

    (** {1:paths Famous file paths} *)

    val null : Fpath.t
    (** [null] represents a file on the OS that discards all writes
        and returns end of file on reads. *)

    val dash : Fpath.t
    (** [dash] is ["-"]. This value is used by {!read} and {!write} to
        respectively denote {!stdin} and {!stdout}. *)

    (** {1:existence Existence} *)

    val exists : Fpath.t -> (bool, string) result
    (** [exists file] is [Ok true] if [file] is a regular file in the
        file system and [Ok false] otherwise. Symbolic links are
        followed. *)

    val must_exist : Fpath.t -> (unit, string) result
    (** [must_exist file] is [Ok ()] if [file] is a regular file in
        the file system and an error otherwise. Symbolic links are
        followed. *)

    val is_executable : Fpath.t -> bool
    (** [is_executable file] is [true] iff [file] exists and is executable. *)

    (** {1:delete_truncate Deleting and truncating} *)

    val delete : Fpath.t -> (bool, string) result
    (** [delete file] deletes file [file] from the file system. If
        [file] is a symbolic link this only deletes the link, not the
        linked file. The result is:
        {ul
        {- [Ok true], if [file] existed and was deleted.}
        {- [Ok false], if the path [file] did not exist on the file system.}
        {- [Error _] in case of error and in particular if [file] is a
           directory.}}
        See also {!Path.delete}. *)

    val truncate : Fpath.t -> int -> (unit, string) result
    (** [trunacte file size] truncates [file] to [size]. *)

    (** {1:hard_links Hard links}

        For symbolic links see {!Path.symlinks}. *)

    val link :
      force:bool -> make_path:bool -> src:Fpath.t -> Fpath.t ->
      (unit, string) result
    (** [link ~force ~src p] hard links file path [p] to the file [src].
        {ul
        {- If [force] is [true] and [p] exists an attempt to delete
           it is performed with {!File.delete}[ p]. If [force] is [false]
           and [p] exists the function errors.}
        {- If [make_path] is [true] and the parent directory of [p] does
           not exist the whole path to the parent is created as needed
           with permission [0o755] (readable and traversable by everyone,
           writable by the user).}} *)

    (** {1:reads Reading} *)

    val read_with_fd :
      Fpath.t -> (Unix.file_descr -> 'b) -> ('b, string) result
    (** [read_with_ic file f] opens [file] as a file descriptor [fdi]
        and returns [Ok (f ic)]. If [file] is {!dash}, [ic] is
        {!stdin}.  After the function returns (normally or via an
        exception raised by [f]), [ic] is ensured to be closed, except
        if it is {!stdin}. The function errors if opening [file]
        fails. *)

    val read_with_ic : Fpath.t -> (in_channel -> 'b) -> ('b, string) result
    (** [read_with_ic file f] is exactly like {!read_with_fd} but
        opens an OCaml input channel. *)

    val read : Fpath.t -> (string, string) result
    (** [read file] is [file]'s content as a string. If [file] is
        {!dash} the contents of {!stdin} is read. {b Warning.} The
        signature of this function limits files to be at most
        {!Sys.max_string_length} in size. On 32-bit platforms this is
        {b only around [16MB]}. *)

    (** {1:writes Writing and copying} *)

    val write_with_fd :
      ?atomic:bool -> ?mode:int -> force:bool -> make_path:bool -> Fpath.t ->
      (Unix.file_descr -> ('a, 'b) Pervasives.result) ->
      (('a, 'b) Pervasives.result, string) result
    (** [write_with_fd ~atomic ~mode ~force ~make_path file f] opens
        an output file descriptor [fdo] to write to [file] and returns
        [Ok (f fdo)].  If [file] is {!dash}, [fdo] is
        {!Unix.stdout}. After the function returns (normally or via an
        exception) [fdo] is ensured to be closed except if it is
        {!Unix.stdout}.
        {ul
        {- If [make_path] is [true] and the parent directory of [file]
           does not exist the whole path to the parent is created as
           needed with permission [0o755] (readable and traversable by
           everyone, writable by the user).}
        {- If [force] is [true] and [file] exists at call time as a
           regular file it tries to overwrite it, in all other cases
           the function errors if [file] exists.}
        {- [mode] are the permissions of the written file; they default to
           [0o644], readable by everyone, writable by the user.}
        {- If [atomic] is [true] (default) and the function or [f]
           errors [file] is left untouched. To write atomically, a
           temporary file [t] in the parent directory of [file] is
           created. On write success [t] is renamed to [file]; an
           operation which is {e more or less} atomic. On error [t] is
           deleted and [file] left intact.  This means the user needs
           write permissions in the parent directory of [file], in
           practice this is almost always the case but fails for some
           directories (e.g. writing to [/sys] on Linux®).
           {b XXX} An improvement would be to automatically disable
           [atomic] on non {!Unix.S_REG} files at the cost of a [stat(2)].}} *)

    val write_with_oc :
      ?atomic:bool -> ?mode:int -> force:bool -> make_path:bool -> Fpath.t ->
      (out_channel -> ('a, 'b) Pervasives.result) ->
      (('a, 'b) Pervasives.result, string) result
    (** [write_with_oc ~atomic ~mode ~force ~make_path file f] operates like
        {!write_with_fd} but opens an OCaml channel. *)

    val write :
      ?atomic:bool -> ?mode:int -> force:bool -> make_path:bool -> Fpath.t ->
      string -> (unit, string) result
    (** [write ~atomic ~mode ~force ~make_path file s] operates like
        {!write_with_fd} but directly writes [s] to [file]. *)

    val copy :
      ?atomic:bool -> ?mode:int -> force:bool -> make_path:bool ->
      src:Fpath.t -> Fpath.t -> (unit, string) result
    (** [copy ~atomic ~mode ~force ~path ~make_path ~src file]
        operates like {!write_with_fd} but directly writes the content
        of [src] (or {!stdin} if [src] is {!dash}) to [file]. [mode] defaults
        to the permissions of [src] if available and [0o644] otherwise. *)

    (** {1:tmpfiles Temporary files} *)

    val with_tmp_fd :
      ?flags:Unix.open_flag list -> ?mode:int -> ?make_path:bool ->
      ?dir:Fpath.t -> ?name:Path.tmp_name ->
      (Fpath.t -> Unix.file_descr -> 'b) -> ('b, string) result
    (** [with_tmp_fd ~flags ~mode ~make_path ~dir ~name f] opens an output file
        descriptor [fdo] to a temporary file and returns [Ok (f fdo)].
        After the function returns (normally or via an exception) [fdo] is
        ensured to be closed and the temporary file is deleted.
        {ul
        {- [name] is used to construct the filename of the file,
           see {!type:tmp_name} for details. It defaults to ["tmp-%s"].}
        {- [dir] is the directory in which the temporary file is created.
           It defaults to {!Dir.default_tmp ()}.}
        {- If [make_path] is [true] (default) and [dir] doesn't exist the
           whole path to it is created as needed with permission [0o755]
           (readable and traversable by everyone, writable by the user).}
        {- [mode] are the permissions of the written file; they
           default to [0o600], only readable and writeable by the user}
        {- [flags] are the flags used to open the file.  They default
           to [Unix.[O_WRONLY; O_CREAT; O_EXCL; O_SHARE_DELETE;
           O_CLOEXEC]]}} *)

    val open_tmp_fd :
      ?flags:Unix.open_flag list -> ?mode:int -> ?make_path:bool ->
      ?dir:Fpath.t -> ?name:Path.tmp_name -> unit ->
      (Fpath.t * Unix.file_descr, string) result
    (** [open_tmp_fd] is like {!with_tmp_fd} except it is the client's
        duty to close the file descriptor and delete the file (if the
        file is not deleted it will be when the program exits). *)

    val with_tmp_oc :
      ?flags:Unix.open_flag list -> ?mode:int -> ?make_path:bool ->
      ?dir:Fpath.t -> ?name:Path.tmp_name -> (Fpath.t -> out_channel -> 'b) ->
      ('b, string) result
    (** [with_tmp_oc] is like {!with_tmp_fd} but uses an OCaml output channel
        instead of a file decriptor. *)
  end

  (** Directory operations.

      This module operates on directories, most functions error if
      they are applied to other file kinds. *)
  module Dir : sig

    (** {1:existence Existence} *)

    val exists : Fpath.t -> (bool, string) result
    (** [exists dir] is [Ok true] if [dir] is a directory in the file system
        and [Ok false] otherwise. Symbolic links are followed. *)

    val must_exist : Fpath.t -> (unit, string) result
    (** [must_exist dir] is [Ok ()] if [dir] is a directory in the file system
        and an error otherwise. Symbolic links are followed. *)

    (** {1:create_delete Creating} *)

    val create : ?mode:int -> make_path:bool -> Fpath.t -> (bool, string) result
    (** [create ~mode ~make_path dir] creates the directory [dir].
        {ul
        {- [mode] are the file permission of [dir]. They default to
           [0o755] (readable and traversable by everyone, writeable by the
           user).}
        {- If [make_path] is [true] and the parent directory of [p] does not
           exist the whole path to the parent is created as needed with
           permission [0o755]
           (readable and traversable by everyone, writable by the user)}}
        The result is:
        {ul
        {- [Ok true] if [dir] did not exist and was created.}
        {- [Ok false] if [dir] did exist as (possibly a symlink to) a
           directory. In this case the mode of [dir] and any other
           directory is kept unchanged.}
        {- [Error _] otherwise and in particular if [dir] exists as a
           non-directory.}} *)

    (** {1:content Contents} *)

    val fold :
      ?rel:bool -> ?dotfiles:bool -> ?follow_symlinks:bool ->
      ?prune:(Unix.stats -> string -> Fpath.t -> bool) -> recurse:bool ->
      (Unix.stats -> string -> Fpath.t -> 'a -> 'a) -> Fpath.t -> 'a ->
      ('a, string) result
    (** [fold ~rel ~dotfiles ~follow_symlinks ~prune ~recurse f dir
        acc] folds [f] over the contents of [dir] starting with
        [acc]. If [dir] does not exist the function errors.
        {ul
        {- [f st name p acc] is called with each path [p] folded over
           with [st] its stat information, [name] its filename and [acc]
           the accumulator.}
        {- If [recurse] is [true] sub-directories [dir] are
           folded over recursively modulo [prune] (see below). If [recurse]
           is false only the direct contents of [dir] is folded over.}
        {- [prune] is called only when [recurse] is [true] as [prune st d]
           with [d] any sub-directory to be folded over and [st] its stat
           information. If the result is [true] [d] and its contents
           are not folded over. Defaults to [fun _ _ _ -> false]}
        {- [follow_symlinks] if [true] (default), symbolic links
           are followed. If [false] symbolic links are not followed
           and the stat information given to [prune] and [f] is
           given by {!Path.symlink_stat}.}
        {- If [dotfiles] is [false] (default) elements whose filename start
           with a [.] are not folded over}
        {- If [rel] is [false] (default) the paths given to [f] and [prune]
           have [dir] prepended, if [true] they are relative to [dir].}}

        {b Fold order.} The fold order is generally undefined. The only
        guarantee is that directory paths are folded over before their
        content.

        {b Warning.} Given the raciness of the POSIX file API it
        cannot be guaranteed that really all existing files will be
        folded over in presence of other processes. *)

    val fold_files :
      ?rel:bool -> ?dotfiles:bool -> ?follow_symlinks:bool ->
      ?prune:(Unix.stats -> string -> Fpath.t -> bool) -> recurse:bool ->
      (Unix.stats -> string -> Fpath.t -> 'a -> 'a) -> Fpath.t -> 'a ->
      ('a, string) result
    (** [fold_files] is like {!fold} but [f] is only applied to
        non-directory files. *)

    val fold_dirs :
      ?rel:bool -> ?dotfiles:bool -> ?follow_symlinks:bool ->
      ?prune:(Unix.stats -> string -> Fpath.t -> bool) -> recurse:bool ->
      (Unix.stats -> string -> Fpath.t -> 'a -> 'a) -> Fpath.t -> 'a ->
      ('a, string) result
    (** [fold_dirs] is like {!fold} but [f] is only applied
        to directory files. *)

    val path_list :
      Unix.stats -> string -> Fpath.t -> Fpath.t list -> Fpath.t list
    (** [path_list] is a {{!fold}folding} function to get a (reverse w.r.t.
        folding order) list of paths. *)

    (** {1:copy Copying} *)

    val copy :
      ?rel:bool -> ?atomic:bool -> ?allow_hardlinks:bool ->
      ?follow_symlinks:bool ->
      ?prune:(Unix.stats -> string -> Fpath.t -> bool) -> make_path:bool ->
      recurse:bool -> src:Fpath.t -> Fpath.t -> (unit, string) result
    (** [copy ~rel ~atomic ~prune ~follow_symlinks ~make_path ~recurse
        ~src dst] copies the directory [src] to [dst]. File modes of
        [src] and its contents are preserved in [dst]. The function
        errors if [dst] exists.
        {ul
        {- If [recurse] is [true] sub-directories of [dir] are also
           copied recursively, unless they are [prune]d (see below).
           If [false] only the files of [src] are copied modulo [prune].
           {b FIXME} I think this is weird}
        {- If [make_path] is [true] and the parent directory of [dst]
           does not exist the whole path to the parent is created as
           needed with permission [0o755] (readable and traversable by
           everyone, writable by the user).}
        {- [prune st name p] is called on each path [p] to copy
           with [st] its stat information and [name] its filename.
           If the function returns [true] the directory or file is not
           copied over. Defaults to [fun _ _ _ -> false].}
        {- If [follow_symlinks] is [true] (default), symlinks are followed.
           If [false] symbolic links are not followed, the actual
           symlinks are copied and the stat information given to [prune]
           is given by {!Os.Path.symlink_stat}.}
        {- [allow_hardlinks] if [true], tries to hard link files from [src]
           at the destination, falling back to copying if that's not possible.
           Defaults to [false].}
        {- [atomic] if atomic is [true] and the function errors then
           [dst] should not exist. To write atomically, a temporary
           directory [t] in the parent directory of [dst] is created.
           On copy success [t] is renamed to [dst]. On error [t] is
           deleted and [dst] left intact.  This means the user needs
           write permissions in the parent directory of [dst], in
           practice this is almost always the case but fails for some
           directories (e.g. writing in [/sys] on Linux®).}
        {- If [rel] is [false] (default) the paths given to [prune]
           have [src] prepended. If [true] they are relative to
           [src].}} *)

    (** {1:cwd Current working directory (cwd)} *)

    val cwd : unit -> (Fpath.t, string) result
    (** [cwd ()] is the current working directory. The resulting path
        is guaranteed to be absolute. *)

    val set_cwd : Fpath.t -> (unit, string) result
    (** [set_cwd dir] sets the current working directory to [dir]. *)

    val with_cwd : Fpath.t -> (unit -> 'a) -> ('a, string) result
    (** [with_cwd dir f] is [f ()] with the current working directory
        bound to [dir]. After the function returns the current working
        directory is back to its initial value. *)

    (** {1:tmp_default Default temporary directory} *)

    val default_tmp : unit -> Fpath.t
    (** [default_tmp ()] is a default directory that can be used
        as a default directory for
        creating {{!File.tmpfiles}temporary files} and
        {{!tmpdirs}directories}. If {!set_default_tmp} hasn't been
        called this is:
        {ul
        {- On POSIX, the value of the [TMPDIR] environment variable or
           [Fpath.v "/tmp"] if the variable is not set or empty.}
        {- On Windows, the value of the [TEMP] environment variable or
           [Fpath.v "."] if it is not set or empty.}} *)

    val set_default_tmp : Fpath.t -> unit
    (** [set_default_tmp p] sets the value returned by {!default_tmp} to
        [p]. *)

    (** {1:tmpdirs Temporary directories} *)

    val with_tmp :
      ?mode:int -> ?make_path:bool -> ?dir:Fpath.t -> ?name:Path.tmp_name ->
      (Fpath.t -> 'a) -> ('a, string) result
    (** [with_tmp ~mode ~make_path ~dir ~name f] creates a temporary empty
        directory [t] and returns Ok (f t). After the function returns
        (normally or via an exception) [t] and its content are deleted.
        {ul
        {- [name] is used to construct the filename of the directory,
           see {!type:File.tmp_name} for details. It defaults to
           ["tmp-%s"].}
        {- [dir] is the directory in which the temporary file is created.
           It defaults to {!Dir.default_tmp ()}.}
        {- If [make_path] is [true] (default) and [dir] doesn't exist the
           whole path to it is created as needed with permission [0o755]
           (readable and traversable by everyone, writable by the user).}
        {- [mode] are the permissions of the temporary directory; they
           default to [0o700], only readable, writeable and traversable
           by the user}} *)

    val tmp :
      ?mode:int -> ?make_path:bool -> ?dir:Fpath.t -> ?name:Path.tmp_name ->
      unit -> (Fpath.t, string) result
    (** [tmp] is like {!with_tmp} except the directory and its content
        is only deleted at the end of program execution if the client
        doesn't do it before. *)

    (** {1:base Base directories}

        The directories returned by these functions are not guaranteed
        to exist. *)

    val user : unit -> (Fpath.t, string) result
    (** [user ()] is the home directory of the user executing the
        process.  Determined by consulting [passwd] database with the
        user if of the process. If this fails or on Windows falls back
        to parse a path from the [HOME] environment variables. *)

    val config : unit -> (Fpath.t, string) result
    (** [config ()] is the directory used to store user-specific program
        configurations. This is in order:
        {ol
        {- If set the value of [XDG_CONFIG_HOME].}
        {- If set and on Windows® the value of [%LOCALAPPDATA%].}
        {- If [user ()] is [Ok home], [Fpath.(home / ".config")].}} *)

    val data : unit -> (Fpath.t, string) result
    (** [data ()] is the directory used to store user-specific program
        data. This is in order:
        {ol
        {- If set the value of [XDG_DATA_HOME].}
        {- If set and on Windows® the value of [%LOCALAPPDATA%].}
        {- If [user ()] is [Ok home], [Fpath.(home / ".local" / "share")].}} *)

    val cache : unit -> (Fpath.t, string) result
    (** [cache ()] is the directory used to store user-specific
        non-essential data. This is in order:
        {ol
        {- If set the value of [XDG_CACHE_HOME].}
        {- If set and on Windows® the value of [%TEMP%]}
        {- If [user ()] is [Ok home], [Fpath.(home / ".cache")]}} *)

    val runtime : unit -> (Fpath.t, string) result
    (** [runtime ()] is the directory used to store user-specific runtime
        files. This is in order:
        {ol
        {- If set the value of [XDG_RUNTIME_HOME].}
        {- The value of {!default_tmp}.}} *)
  end

  (** File descriptors operations. *)
  module Fd : sig

    val unix_buffer_size : int
    (** [unix_buffer_size] is the value of the OCaml runtime
        system buffer size for I/O operations. *)

    val apply :
      close:(Unix.file_descr -> unit) -> Unix.file_descr ->
      (Unix.file_descr -> 'a) -> 'a
    (** [apply ~close fd f] calls [f fd] and ensure [close fd] is
        is called whenever the function returns. Any {!Unix.Unix_error}
        raised by [close fd] is ignored. *)

    val copy : ?buf:Bytes.t -> src:Unix.file_descr -> Unix.file_descr -> unit
    (** [copy ~buf ~src dst] reads [src] and writes it to [dst] using
        [buf] as a buffer; if unspecified a buffer of length
        {!unix_buffer_size} is created for the call. @raise Unix_error
        if that happens *)

    val to_string : Unix.file_descr -> string
    (** [to_string fd] reads [fd] to a string. @raise Unix_error in case
        of error. *)

    val read_file : string -> Unix.file_descr -> string
    (** [read_file fn fd] reads [fd] to a string assuming it is a file
        descriptor open on file path [fn].

        @raise Failure in case of error with an error message that
        mentions [fn]. *)
  end

  (** Executing commands. *)
  module Cmd : sig

    (** {1:search Tool search}

      {b Portability.} In order to maximize portability no [.exe]
      suffix should be added to executable names on Windows, tool
      search adds the suffix during the tool search procedure. *)

    val find_tool :
      ?search:Fpath.t list -> Cmd.tool -> (Fpath.t option, string) result
    (** [find_tool ~search tool] is the file path, if any, to the program
        executable for the tool specification [tool].
        {ul
        {- If [tool] has a single path segment. The [tool] file is
           searched, in list order, for the first matching executable
           file in the directories of [search]. These directories
           default to those that result from parsing [PATH] with
           {!Fpath.list_of_search_path}.}
        {- If [tool] has multiple path segments the corresponding file
           is simply tested for {{!File.is_executable}existence and
           executability}.  [Ok (Some tool)] is returned if that is
           case and [Ok None] otherwise.}} *)

    val must_find_tool :
      ?search:Fpath.t list -> Cmd.tool -> (Fpath.t, string) result
    (** [must_find_tool] is like {!find_tool} except it errors if [Ok None]
        is returned. *)

    val find_first_tool :
      ?search:Fpath.t list -> Cmd.tool list -> (Fpath.t option, string) result
    (** [find_first_tool] is the first tool that can be found in the list
        with {!find_tool}. *)

    val find :
      ?search:Fpath.t list -> Cmd.t -> (Cmd.t option, string) result
    (** [find ~search cmd] resolves [cmd]'s tool as {!find_tool} does. *)

    val must_find :
      ?search:Fpath.t list -> Cmd.t -> (Cmd.t, string) result
    (** [must_find ~search cmd] resolves [cmd]'s tool as {!must_find_tool}
        does. *)

    val find_first :
      ?search:Fpath.t list -> Cmd.t list -> (Cmd.t option, string) result
    (** [find_first ~search cmds] resolves [cmds]'s {!Cmd.too}s
        as {!find_first_tool} does. *)

    (** {1:statuses Process completion statuses} *)

    type status = [ `Exited of int | `Signaled of int ]
    (** The type for process exit statuses. *)

    val pp_status : status Fmt.t
    (** [pp_status] is a formatter for process exit statuses. *)

    val pp_cmd_status : (Cmd.t * status) Fmt.t
    (** [pp_cmd_status] is a formatter for command process exit statuses. *)

    (** {1:stdis Process standard inputs} *)

    type stdi
    (** The type for representing the standard input of a process. *)

    val in_string : string -> stdi
    (** [in_string s] is a standard input that reads the string [s]. *)

    val in_file : Fpath.t -> stdi
    (** [in_file f] is a standard input that reads from file [f]. *)

    val in_fd : close:bool -> Unix.file_descr -> stdi
    (** [in_fd ~close fd] is a standard input that reads from file
        descriptor [fd]. If [close] is [true], [fd] is closed after
        the process is spawn. *)

    val in_stdin : stdi
    (** [in_stdin] is [in_fd ~close:false Unix.stdin], a standard
        input that reads from the current process standard input. *)

    val in_null : stdi
    (** [in_null] is [in_file File.null]. *)

    (** {1:stdos Process standard outputs} *)

    type stdo
    (** The type for representing the standard output of a process. *)

    val out_file : Fpath.t -> stdo
    (** [out_file f] is a standard output that writes to file [f]. *)

    val out_fd : close:bool -> Unix.file_descr -> stdo
    (** [out_fd ~close fd] is a standard output that writes to file
        descriptor [fd]. If [close] is [true], [fd] is closed after
        the process spawn. *)

    val out_stdout : stdo
    (** [out_stdout] is [out_fd ~close:false Unix.stdout] *)

    val out_stderr : stdo
    (** [out_stderr] is [out_fd ~close:false Unix.stderr] *)

    val out_null : stdo
    (** [out_null] is [out_file File.null] *)

    (** {1:run Command execution} *)

    (** {2:run_block Blocking}

        These functions wait for the command to complete before
        proceeding. *)

    val run_status :
      ?env:Env.assignments -> ?cwd:Fpath.t -> ?stdin:stdi -> ?stdout:stdo ->
      ?stderr:stdo -> Cmd.t -> (status, string) result
    (** [run_status ~env ~cwd ~stdin ~stdout ~stderr cmd] runs and
        waits for the completion of [cmd] in environment [env] with
        current directory [cwd] and standard IO connections [stdin],
        [stdout] and [stderr].
        {ul
        {- [env] defaults to {!Env.current_assignments}[ ()]}
        {- [cwd] defaults to {!Dir.cwd}[ ()]}
        {- [stdin] defaults to {!in_stdin}}
        {- [stdout] defaults to {!out_stdout}}
        {- [stderr] defaults to {!out_stderr}}}. *)

    val run_status_out :
      ?env:Env.assignments -> ?cwd:Fpath.t -> ?stdin:stdi ->
      ?stderr:[`Stdo of stdo | `Out] -> ?trim:bool -> Cmd.t ->
      (status * string, string) result
    (** [run_status_out] is like {!run_status} except [stdout] is read
        from the process to a string. The string is {!String.trim}ed
        if [trim] is [true] (default). If [stderr] is [`Out] the
        process' [stderr] is redirected to [stdout] and thus read back
        in the string aswell. *)

    val run :
      ?env:Env.assignments -> ?cwd:Fpath.t -> ?stdin:stdi -> ?stdout:stdo ->
      ?stderr:stdo -> Cmd.t -> (unit, string) result
    (** [run] is {!run_status} with non-[`Exited 0] statuses turned
        into errors via {!pp_cmd_status}. *)

    val run_out :
      ?env:Env.assignments -> ?cwd:Fpath.t -> ?stdin:stdi ->
      ?stderr:[`Stdo of stdo | `Out] -> ?trim:bool -> Cmd.t ->
      (string, string) result
    (** [run] is {!run_status_out} with non-[`Exited 0] statuses
        turned into errors via {!pp_cmd_status}. *)

    (** {2:spawn Non-blocking}

        {b Note.} In contrast to [waitpid(2)] the following API does
        not allow to collect {e any} child process completion. There
        are two reasons: first this is not supported on Windows,
        second this is anti-modular. *)

    type pid
    (** The type for process identifiers. *)

    val pid_to_int : pid -> int
    (** [pid_to_int pid] is the system identifier for process
        identifier [pid]. *)

    val spawn :
      ?env:Env.assignments -> ?cwd:Fpath.t -> ?stdin:stdi -> ?stdout:stdo ->
      ?stderr:stdo -> Cmd.t -> (pid, string) result
    (** [spawn ~env ~cwd ~stdin ~stdout ~stderr cmd] spawns command
        [cmd] in environment [env] with current directory [cwd] and
        standard IO connections [stdin], [stdout] and [stderr]. [env]
        defaults to {!Env.current_assignments}[ ()], [cwd] to {!Dir.current}[
        ()], [stdin] to {!in_stdin}, [stdout] to {!out_stdout} and
        [stderr] to {!out_stderr}. *)

    val spawn_poll_status : pid -> (status option, string) result
    (** [spawn_poll_status pid] tries to collect the exit status of
        command spawn [pid]. If [block] is [false], [Ok None] is immediately
        returned if [pid] has not terinated yet. *)

    val spawn_wait_status : pid -> (status, string) result
    (** [spawn_wait_status] blocks and waits for [pid]'s termination status to
        become available. *)

    (** {2:tracing Tracing} *)

    type spawn_tracer =
      pid -> Env.assignments option -> cwd:Fpath.t option -> Cmd.t -> unit
    (** The type for spawn tracers. Called with each blocking
        and non-blocking spawned command. The function is given the process
        identifier of the spawn, the environment if different from
        the program's one, the current working directory if different
        from the program's one and the acctual command. *)

    val spawn_tracer_nop : spawn_tracer
    (** [spawn_tracer_nop] is a spawn tracer that does nothing.
        This is the initial spawn tracer. *)

    val spawn_tracer : unit -> spawn_tracer
    (** [tracer ()] is the current spawn tracer. Initially this is
        {!spawn_tracer_nop}. *)

    val set_spawn_tracer : spawn_tracer -> unit
    (** [set_tracer t] sets the current spawn tracer to [t]. *)

    (** {1:exec Executing files}

        {b Windows.} On Windows a program executing an [execv*]
        function yields back control to the terminal as soon as the
        child starts (vs. ends on POSIX). This entails all sorts of
        unwanted behaviours. To workaround this, the following
        function executes, on Windows, the file as a spawned child
        process which is waited on for completion via
        [waitpid(2)]. Once the child process has terminated the
        calling process is immediately [exit]ed with the status of the
        child. *)

    val execv :
      ?env:Env.assignments -> ?cwd:Fpath.t -> Fpath.t -> Cmd.t ->
      (unit, string) result
    (** [execv ~env ~cwd f argv] executes file [f] as a new process in
        environment [env] with [args] as the {!Sys.argv} of this
        process (in particular [Sys.argv.(0)] is the name of the
        program not the first argument to the program). The function
        only recturns in case of error. [env] defaults to
        {!B0.OS.Env.current_assignments}[ ()], [cwd] to {!Dir.current}[ ()]. *)
  end
end

(** Program log.

    Support for program logging. Not to be used by build logic.

    The module is modelled after {!Logs} logging, see
    {{!Logs.basics}this quick introduction}. It can be made
    to log on a {!Logs} source, see {{!logger}here}.

    {b FIXME} This should maybe moved to B0_ui. Make the doc self
    contained (cf. references to Logs). *)
module Log : sig

  (** {1:levels Reporting levels} *)

  type level = Quiet | App | Error | Warning | Info | Debug (** *)
  (** The type for reporting levels. They are meant to be used
      as follows:
      {ul
      {- [Quiet] doesn't report anything.}
      {- [App] can be used for the standard output or console
         of an application. Using this instead of [stdout] directly
         allows the output to be silenced by [Quiet] which may
         be desirable, or not.}
      {- [Error] is an error condition that prevents the program from
          running.}
      {- [Warning] is a suspicious condition that does not prevent
         the program from running normally but may eventually lead to
         an error condition.}
      {- [Info] is a condition that allows the program {e user} to
         get a better understanding of what the program is doing.}
      {- [Debug] is a condition that allows the program {e developer}
         to get a better understanding of what the program is doing.}} *)

  val level : unit -> level
  (** [level ()] is the current reporting level. *)

  val set_level : level -> unit
  (** [set_level l] sets the current reporting level to [l]. *)

  val pp_level : level Fmt.t
  (** [pp_level ppf l] prints and unspecified representation of [l]
      on [ppf]. *)

  val level_to_string : level -> string
  (** [level_to_string l] converts [l] to a string representation. *)

  val level_of_string : string -> (level, string) Pervasives.result
  (** [level_of_string s] parses a level from [s] according to the
      representation of {!level_to_string}. *)

  (** {1:func Log functions} *)

  type ('a, 'b) msgf =
    (?header:string -> ('a, Format.formatter, unit, 'b) format4 -> 'a) -> 'b
  (** The type for client specified message formatting functions. See
      {!Logs.msgf}. *)

  type 'a log = ('a, unit) msgf -> unit
  (** The type for log functions. See {!Logs.log}. *)

  val msg : level -> 'a log
  (** See {!Logs.msg}. *)

  val quiet : 'a log
  (** [quiet] is [msg Quiet]. *)

  val app : 'a log
  (** [app] is [msg App]. *)

  val err : 'a log
  (** [err] is [msg Error]. *)

  val warn : 'a log
  (** [warn] is [msg Warning]. *)

  val info : 'a log
  (** [info] is [msg Info]. *)

  val debug : 'a log
  (** [debug] is [msg Debug]. *)

  val kmsg : (unit -> 'b) -> level -> ('a, 'b) msgf -> 'b
  (** [kmsg k level m] logs [m] with level [level] and continues with [k]. *)

  (** {2:result Logging [result] value [Error] messages} *)

  val if_error :
    ?level:level -> ?header:string -> use:'a ->
    ('a, string) Pervasives.result -> 'a
  (** [if_error ~level ~use v r] is:
      {ul
      {- [v], if [r] is [Ok v]}
      {- [use] and [e] is logged with [level] (defaults to [Error]), if
         [r] is [Error e].}} *)

  val warn_if_error :
    ?header:string -> use:'a -> ('a, string) Pervasives.result -> 'a
  (** [warn_if_error] is [if_error ~level:Warning]. *)

  val if_error_pp :
    ?level:level -> ?header:string -> 'b Fmt.t -> use:'a ->
    ('a, 'b) Pervasives.result -> 'a
  (** [if_error_pp ~level pp ~use r] is
      {ul
      {- [v], if [r] is [Ok v].}
      {- [use] and [e] is logged with [level] (defaults to [Error]) using
         [pp], if [r] is [Error e].}} *)

  (** {2:timing Logging timings} *)

  val time :
    ?level:level ->
    ('a -> (('b, Format.formatter, unit, 'a) format4 -> 'b) -> 'a) ->
    (unit -> 'a) -> 'a
  (** [time ~level m f] logs [m] with level [level] (defaults to
      [Info]) and the time [f ()] took as the log header. *)

  (** {1:monitoring Log monitoring} *)

  val err_count : unit -> int
  (** [err_count ()] is the number of messages logged with level
      [Error]. *)

  val warn_count : unit -> int
  (** [warn_count ()] is the number of messages logged with level
      [Warning]. *)

  (** {1:logger Logger}

      The following function allows to change the logging backend.
      Note that in this case {{!monitoring}monitoring} and
      {{!levels}level} functions are no longer relevant. *)

  type kmsg = { kmsg : 'a 'b. (unit -> 'b) -> level -> ('a, 'b) msgf -> 'b }
  (** The type for the basic logging function. The function is never
      invoked with a level of [Quiet]. *)

  val kmsg_nop : kmsg
  (** [nop_kmsg] is a logger that does nothing. *)

  val kmsg_default : kmsg
  (** [kmsg_default] is the default logger that logs messages on
      {!Fmt.stderr} except for {!Log.App} level which logs on
      {!Fmt.stdout}. *)

  val set_kmsg : kmsg -> unit
  (** [set_kmsg kmsg] sets the logging function to [kmsg]. *)
end

(*---------------------------------------------------------------------------
   Copyright (c) 2018 The b0 programmers

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)