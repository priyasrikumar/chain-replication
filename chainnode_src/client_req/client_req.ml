type req = Query of string | Update of string * int 

let is_query str =
  match str with
  | "Query" -> true
  | "Update" -> false
  | _ -> failwith "Impossible case: to_ack."

let mk_query ~var:var = Query var
let mk_update ~var:var ~num:num = Update (var,num)
