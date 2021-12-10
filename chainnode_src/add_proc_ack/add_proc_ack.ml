type ack = Ok | NotHead

let ok = Ok
let not_head = NotHead 

let to_str ack =
  match ack with
  | Ok -> "Ok"
  | NotHead -> "NotHead"
let to_ack str =
  match str with
  | "Ok" -> Ok
  | "NotHead" -> NotHead
  | _ -> failwith "Impossible case: to_ack."
