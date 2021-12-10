type ack = Found of int | NotFound | Ok | NotHead | NotTail

let found i = Found i
let not_found = NotFound
let ok = Ok
let not_head = NotHead 
let not_tail = NotTail

let to_str ack =
  match ack with
  | Found _ -> "Found"
  | NotFound -> "NotFound"
  | Ok -> "Ok"
  | NotHead -> "NotHead"
  | NotTail -> "NotTail"
let to_ack ?(i = 0) str =
  match str with
  | "Found" -> Found (i)
  | "NotFound" -> NotFound
  | "Ok" -> Ok
  | "NotHead" -> NotHead
  | "NotTail" -> NotTail
  | _ -> failwith "Impossible case: to_ack."
