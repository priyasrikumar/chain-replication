type req = AddProc of string * int

val mk_add_proc : ipv4:string -> port:int -> req

val get_add_proc : req -> (string * int)
