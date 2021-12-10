type ack = Found of int | NotFound | Ok | NotHead | NotTail

val found : int -> ack
val not_found : ack 
val ok : ack 
val not_head : ack
val not_tail : ack 

val to_str : ack -> string
val to_ack : ?i:int -> string -> ack
