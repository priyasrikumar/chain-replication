(**
  * start the server with a list of potential nodes
  * it can send and add_proc to join the chain
  * this function returns true if the node has joined
  * the chain and otherwise false
  *)
val attempt_join : ipv4:string -> port:int -> potential_heads:(string * int) list -> bool Async_unix__.Import.Deferred.t
