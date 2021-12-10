type client_req =
    Update of string * int
  | Query of string

type client_ack =
    Found of int
  | NotFound
  | Ok
  | NotHead of string * int
  | NotTail of string * int 

val mk_update : var:string -> num:int -> client_req
val mk_query : var:string -> client_req
