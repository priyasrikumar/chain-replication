open Core
open Yojson.Basic

open Client_data

let raise_invalid_arg str json =
  Invalid_argument (Printf.sprintf "%s: %s" str (to_string json)) |> raise

let mk_req req =
  match req with
  | Query (var) ->
    let typ = `String ("Query") in
    let data = `Assoc ([("var",`String var)]) in
    `Assoc ([("typ", typ); ("data", data)])
  | Update (var, num) ->
    let typ = `String ("Update") in
    let data = `Assoc ([("var",`String (var)); ("val",`Int (num))]) in
    `Assoc ([("typ", typ); ("data", data)])

let process_ack ack =
  let open Util in
  try
    match ack |> member "type" |> to_string with
    | "Found" ->
      let num = ack |> member "data" |> to_int in
      Found (num)
    | "NotFound" -> NotFound
    | "Ok" -> Ok
    | "NotHead" ->
      let ipv4 = ack |> member "data" |> member "ipv4" |> to_string in
      let port = ack |> member "data" |> member "port" |> to_int in
      NotHead (ipv4, port)
    | "NotTail" ->
      let ipv4 = ack |> member "data" |> member "ipv4" |> to_string in
      let port = ack |> member "data" |> member "port" |> to_int in
      NotTail (ipv4, port)
    | _ -> failwith "Inocrrectly formatted ack from server."
  with _ -> raise_invalid_arg "Bad entry" ack
