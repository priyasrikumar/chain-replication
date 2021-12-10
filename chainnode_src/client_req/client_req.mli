type req = Query of string | Update of string * int 

val is_query : string -> bool

val mk_query : var:string -> req
val mk_update : var:string -> num:int -> req
