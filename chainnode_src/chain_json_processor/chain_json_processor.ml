open Core
open Yojson.Basic

open Chain_log

let raise_invalid_arg str json =
  Invalid_argument (Printf.sprintf "%s: %s" str (to_string json)) |> raise

let log_entry_to_json_entry log_entry =
  let data = ("data", `Assoc ([("var", `String (log_entry.str)); ("val", `Int (log_entry.num))])) in
  let id = ("id", `Assoc ([("fst", `Int (fst log_entry.uid)); ("snd", `Int (snd log_entry.uid))])) in
  let typ = match log_entry.typ with
    | ClientUpdate -> ("type", `String ("ClientUpdate"))
    | AddProc -> ("type", `String ("AddProc"))
  in
  `Assoc ([typ; data; id])

let json_entry_to_log_entry json_entry =
  let open Util in 
  try
    let str = json_entry |> member "data" |> member "var" |> to_string in
    let num = json_entry |> member "data" |> member "val" |> to_int in
    let ida = json_entry |> member "id" |> member "fst" |> to_int in
    let idb = json_entry |> member "id" |> member "snd" |> to_int in
    let typ = match json_entry |> member "type" |> to_string with
      | "ClientUpdate" -> ClientUpdate
      | "AddProc" -> AddProc
      | _ -> failwith "Impossible case, type missing for json log entry."
    in
    { str = str; num = num; typ = typ; uid = (ida, idb) }
  with _ -> raise_invalid_arg "Bad entry" json_entry

let parse_json_log json = Util.(json |> to_list |> List.mapi ~f:(fun _ json_entry -> json_entry_to_log_entry json_entry))

let make_json_log log = `List (log |> List.mapi ~f:(fun _ log_entry -> log_entry_to_json_entry log_entry))

let checkin_req_to_json_checkin_req req = `Assoc ([("req", `String (Checkin_req.to_str req))])

let json_checkin_req_to_checkin_req json_req =
  let open Util in
  try
    json_req |> member "req" |> to_string |> Checkin_req.to_req 
  with _ -> raise_invalid_arg "Bad entry" json_req

let chain_ack_to_json_chain_ack ack = `Assoc ([("ack", `String (Chain_ack.to_str ack))])

let json_chain_ack_to_chain_ack json_ack = 
  let open Util in
  try
    json_ack |> member "ack" |> to_string |> Chain_ack.to_ack 
  with _ -> raise_invalid_arg "Bad entry" json_ack

let add_proc_req_json_to_add_proc_req req =
  let open Util in
  try
    let ipv4 = req |> member "ipv4" |> to_string in
    let port = req |> member "port" |> to_int in
    Add_proc_req.mk_add_proc ~ipv4:ipv4  ~port:port
  with _ -> raise_invalid_arg "Bad entry" req
  
let add_proc_req_to_add_proc_req_json req =
  let (ipv4, port) = Add_proc_req.get_add_proc req in
  `Assoc ([("ipv4", `String (ipv4)); ("port", `Int (port))])

let add_proc_ack_to_json_add_proc_ack ack =
  let open Add_proc_ack in
  let typ = `String (Add_proc_ack.to_str ack) in
  let data = 
    match ack with
    | Ok -> Chain_log.to_send () |> make_json_log
    | NotHead -> 
      let (ipv4,port) = Option.value_map (Chain_config.get_head ()) ~default:("0.0.0.0",0) ~f:ident in
      `Assoc ([("ipv4", `String (ipv4)); ("port", `Int (port))])
  in
  `Assoc ([("type", typ); ("data", data)])

let client_req_json_to_client_req req =
  let open Util in
  try
    if req |> member "typ" |> to_string |> Client_req.is_query then
      let str = req |> member "data" |> member "var" |> to_string in
      Client_req.mk_query ~var:str 
    else
      let str = req |> member "data" |> member "var" |> to_string in
      let num = req |> member "data" |> member "val" |> to_int in
      Client_req.mk_update ~var:str ~num:num
  with _ -> raise_invalid_arg "Bad entry" req

let client_ack_to_json_client_ack ack =
  let open Client_ack in
  let typ = `String (Client_ack.to_str ack) in
  let data = 
    match ack with
    | Found i -> `Int (i)
    | NotFound -> `Int (0)
    | Ok -> `String ("")
    | NotHead ->
      let (ipv4,port) = Option.value_map (Chain_config.get_head ()) ~default:("0.0.0.0",0) ~f:ident in
      `Assoc ([("ipv4", `String (ipv4)); ("port", `Int (port+2))])
    | NotTail -> 
      let (ipv4,port) = Option.value_map (Chain_config.get_tail ()) ~default:("0.0.0.0",0) ~f:ident in
      `Assoc ([("ipv4", `String (ipv4)); ("port", `Int (port+2))])
  in 
  `Assoc ([("type", typ); ("data", data)])
