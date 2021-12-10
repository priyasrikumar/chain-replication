type req = Checkin

let checkin = Checkin

let to_str req =
  match req with
  | Checkin -> "Checkin"
let to_req str =
  match str with
  | "Checkin" -> Checkin
  | _ -> failwith "Impossible case: to_req."