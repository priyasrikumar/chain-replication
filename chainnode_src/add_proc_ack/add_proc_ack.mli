type ack = Ok | NotHead

val ok : ack 
val not_head : ack

val to_str : ack -> string
val to_ack : string -> ack
