type ack = Ok | NotOk

val ok : ack
val not_ok : ack 

val is_ok : ack -> bool

val to_str : ack -> string
val to_ack : string -> ack
