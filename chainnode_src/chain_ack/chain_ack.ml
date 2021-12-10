type ack = Ok | NotOk

let ok = Ok
let not_ok = NotOk 

let is_ok ack = ack = Ok

let to_str ack =
  match ack with
  | Ok -> "Ok"
  | NotOk -> "NotOk"
let to_ack str =
  match str with
  | "Ok" -> Ok
  | "NotOk" -> NotOk
  | _ -> failwith "Impossible case: to_ack."
