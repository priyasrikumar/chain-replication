val add_head : ipv4:string -> port:int -> unit
val add_tail : ipv4:string -> port:int -> unit

val kill_head : unit -> unit
val kill_tail : unit -> unit

val get_head : unit -> (string * int) Core.Option.t
val get_tail : unit -> (string * int) Core.Option.t
