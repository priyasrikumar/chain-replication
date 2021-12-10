type req = AddProc of string * int

let mk_add_proc ~ipv4:ipv4 ~port:port = AddProc ((ipv4,port))

let get_add_proc req =
  match req with
  | AddProc ((ipv4,port)) -> (ipv4,port)
