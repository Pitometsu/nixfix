let[@inline] get x i = String.unsafe_get x i |> Char.code

(* XXX(dinosaure): we use [unsafe_get] to avoid jump to exception:

        sarq    $1, %rbx
        movzbq  (%rax,%rbx), %rax
        leaq    1(%rax,%rax), %rax
        ret
*)

external unsafe_get_int16 : string -> int -> int = "%caml_string_get16u"
let[@inline] get16 x i = unsafe_get_int16 x i

(* XXX(dinosaure): same as [unsafe_get] but for [int16]:

        sarq    $1, %rbx
        movzwq  (%rax,%rbx), %rax
        leaq    1(%rax,%rax), %rax
        ret
*)

let equal ~ln a b =
  let l1 = ln asr 1 in

  (*
        sarq    $1, %rcx
        orq     $1, %rcx
  *)

  let r = ref 0 in

  (*
        movq    $1, %rdx
  *)

  for i = 0 to pred l1 do r := !r lor (get16 a (i * 2) lxor get16 b (i * 2)) done ;

  (*
        movq    $1, %rsi
        addq    $-2, %rcx
        cmpq    %rcx, %rsi
        jg      .L104
.L105:
        leaq    -1(%rsi,%rsi), %r8

        sarq    $1, %r8
        movzwq  (%rdi,%r8), %r9
        leaq    1(%r9,%r9), %r9
        movzwq  (%rbx,%r8), %r8
        leaq    1(%r8,%r8), %r8

     // [unsafe_get_int16 a i] and [unsafe_get_int6 b i]

        xorq    %r9, %r8
        orq     $1, %r8
        orq     %r8, %rdx
        movq    %rsi, %r8
        addq    $2, %rsi
        cmpq    %rcx, %r8
        jne     .L105
.L104:
  *)

  for _ = 1 to ln land 1 do r := !r lor (get a (ln - 1) lxor get b (ln - 1)) done ;

  (*
        movq    $3, %rsi
        movq    %rax, %rcx
        andq    $3, %rcx
        cmpq    %rcx, %rsi
        jg      .L102
.L103:
        movq    %rax, %r8
        addq    $-2, %r8

        sarq    $1, %r8
        movzbq  (%rdi,%r8), %r9
        leaq    1(%r9,%r9), %r9
        movzbq  (%rbx,%r8), %r8
        leaq    1(%r8,%r8), %r8

     // [unsafe_get a i] and [unsafe_get b i]

        xorq    %r9, %r8
        orq     $1, %r8
        orq     %r8, %rdx
        movq    %rsi, %r8
        addq    $2, %rsi
        cmpq    %rcx, %r8
        jne     .L103
.L102:
  *)

  !r = 0

(*
        cmpq    $1, %rdx
        sete    %al
        movzbq  %al, %rax
        leaq    1(%rax,%rax), %rax
        ret
*)

let[@inline] min (a:int) b = if a < b then a else b
(* XXX(dinosaure): we should delete the branch, TODO! *)

let equal a b =
  let al = String.length a in
  let bl = String.length b in
  let ln = min al bl in
  if (al lxor ln) lor (bl lxor ln) <> 0
  then false
  else equal ~ln a b
