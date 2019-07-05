type token =
  | TokEof of (Lm_location.t)
  | TokEol of (Lm_location.t)
  | TokWhite of (string * Lm_location.t)
  | TokLeftParen of (string * Lm_location.t)
  | TokRightParen of (string * Lm_location.t)
  | TokArrow of (string * Lm_location.t)
  | TokComma of (string * Lm_location.t)
  | TokColon of (string * Lm_location.t)
  | TokDoubleColon of (string * Lm_location.t)
  | TokNamedColon of (string * Lm_location.t)
  | TokDollar of (string * Omake_ast.apply_strategy * Lm_location.t)
  | TokEq of (string * Lm_location.t)
  | TokArray of (string * Lm_location.t)
  | TokDot of (string * Lm_location.t)
  | TokId of (string * Lm_location.t)
  | TokKey of (string * Lm_location.t)
  | TokKeyword of (string * Lm_location.t)
  | TokCatch of (string * Lm_location.t)
  | TokClass of (string * Lm_location.t)
  | TokOp of (string * Lm_location.t)
  | TokInt of (string * Lm_location.t)
  | TokFloat of (string * Lm_location.t)
  | TokString of (string * Lm_location.t)
  | TokBeginQuote of (string * Lm_location.t)
  | TokEndQuote of (string * Lm_location.t)
  | TokBeginQuoteString of (string * Lm_location.t)
  | TokEndQuoteString of (string * Lm_location.t)
  | TokStringQuote of (string * Lm_location.t)
  | TokVar of (Omake_ast.apply_strategy * string * Lm_location.t)
  | TokVarQuote of (Omake_ast.apply_strategy * string * Lm_location.t)

val deps :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> (Omake_ast.exp * Omake_ast.exp * Lm_location.t) list
val shell :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Omake_ast.body_flag * Omake_ast.exp
val string :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Omake_ast.body_flag * Omake_ast.exp
