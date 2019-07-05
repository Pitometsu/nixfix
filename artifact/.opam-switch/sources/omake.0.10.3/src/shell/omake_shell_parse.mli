type token =
  | TokEof of (Lm_location.t)
  | TokValues of (Omake_value_type.t list * Lm_location.t)
  | TokDefine of (string * Lm_location.t)
  | TokLeftParen of (string * Lm_location.t)
  | TokRightParen of (string * Lm_location.t)
  | TokLessThan of (string * Lm_location.t)
  | TokGreaterThan of (string * Lm_location.t)
  | TokGreaterGreaterThan of (string * Lm_location.t)
  | TokAmp of (string * Lm_location.t)
  | TokPipe of (string * Lm_location.t)
  | TokSemiColon of (string * Lm_location.t)
  | TokAnd of (string * Lm_location.t)
  | TokOr of (string * Lm_location.t)

val prog :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Omake_env.value_pipe
