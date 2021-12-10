type client_req =
    Update of string * int
  | Query of string

type client_ack =
    Found of int
  | NotFound
  | Ok
  | NotHead of string * int
  | NotTail of string * int 

let mk_update ~var:var ~num:num = Update ((var,num))
let mk_query ~var:var = Query (var)
