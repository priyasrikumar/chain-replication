open Async
open Core

type t = Tcp.Server.inet

let magic = 128 + 3

let mk_ack ok = if ok then Chain_ack.ok else Chain_ack.not_ok

let ok_msg addr ok =
  if ok then begin 
    Async.Print.printf " Request is ok.\n>> ";
    let ipv4, port = Async_unix.Socket.Address.Inet.to_host_and_port addr |> Host_and_port.tuple in
    Chain_config.recv_msg ~ipv4:ipv4 ~port:port
  end else begin
    Async.Print.printf " Request is not ok.\n>> "
  end;
  ok 

let client_json_process addr json =
  let open Yojson.Basic.Util in
  try
    match json |> member "msg_typ" |> to_string with
    | "Log" -> begin
      Async.Print.printf "Got a log from %s." (Async_unix.Socket.Address.Inet.to_string addr);
      after (Time.Span.create ~ms:20 ()) >>=
      (fun () -> json |> member "contents" |> Chain_json_processor.parse_json_log |> Chain_log.receive_log |> ok_msg addr |> return)
    end
    | "Checkin" -> begin
      Async.Print.printf "Got a checkin from %s." (Async_unix.Socket.Address.Inet.to_string addr);
      json |> member "contents" |> Chain_json_processor.json_checkin_req_to_checkin_req |> (fun _ -> true) |> ok_msg addr |> return
    end
    | _ -> failwith "Impossible case, msg_typ missing for chain message."
  with _ -> Chain_json_processor.raise_invalid_arg "Bad entry" json

let handler addr r w =
  let buf = Buffer.create ((Chain_log.size () + 1) * magic) in
  let rec read_line () =
    Reader.read_char r >>=
    (function
      | `Ok ('\n') -> return ()
      | `Ok (c) -> Buffer.add_char buf c |> read_line
      | `Eof -> return ())
  in
  read_line () >>=
  (fun () -> Buffer.contents buf |> Yojson.Basic.from_string |> client_json_process addr) >>|
  (fun ok -> mk_ack ok |> Chain_json_processor.chain_ack_to_json_chain_ack |> Yojson.Basic.to_string |> Writer.write_line w)

let mk ~ipv4:ipv4 ~port:port =
  let inet_addr = Tcp.Bind_to_address.Address (Unix.Inet_addr.of_string ipv4) in
  let port_addr = Tcp.Bind_to_port.On_port port in
  let where_to_listen = Tcp.Where_to_listen.bind_to inet_addr port_addr in
  Tcp.Server.create
    ~on_handler_error:`Ignore
      where_to_listen
      handler

let rm server = Tcp.Server.close server
