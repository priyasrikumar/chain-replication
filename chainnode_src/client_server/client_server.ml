open Async
open Core

type t = Tcp.Server.inet

let handler addr r w =
  let buf = Buffer.create 100 in
  let rec read_line () =
    Reader.read_char r >>=
    (function
      | `Ok ('\n') -> return ()
      | `Ok (c) -> Buffer.add_char buf c |> read_line
      | `Eof -> return ())
  in
  read_line () >>|
  (fun () -> Buffer.contents buf |> Yojson.Basic.from_string |> Chain_json_processor.client_req_json_to_client_req) >>=
  (fun req ->
    let open Client_req in 
    match req with
    | Query (str) -> begin
      if Chain_config.is_tail () then begin
        Async.Print.printf "Got a query request from client %s. Accepted because server is tail.\n>> " (Async_unix.Socket.Address.Inet.to_string addr);
        after (Time.Span.create ~ms:5 ()) >>|
        (fun () ->
          Option.value_map
            (Database.get ~key:str)
            ~default:Client_ack.NotFound
            ~f:(fun i -> Client_ack.Found (i)))
      end else begin
        Async.Print.printf "Got a query request from client %s. Rejected because server is not head.\n>> " (Async_unix.Socket.Address.Inet.to_string addr);
        return Client_ack.NotTail
      end
    end
    | Update (str,num) ->
      if Chain_config.is_head () then begin
        Async.Print.printf "Got an update request from client %s. Accepted because server is head.\n>> " (Async_unix.Socket.Address.Inet.to_string addr);
        let ipv4, port = Async_unix.Socket.Address.Inet.to_host_and_port addr |> Host_and_port.tuple in
        after (Time.Span.create ~ms:50 ()) >>|
        (fun () -> 
          Chain_log.client_update ~ipv4:ipv4 ~port:port ~var:str ~num:num;
          Database.add ~key:str ~num:num;
          Client_ack.Ok)
      end else begin 
        Async.Print.printf "Got an update request from client %s. Rejected because server is not head.\n>> " (Async_unix.Socket.Address.Inet.to_string addr);
        return Client_ack.NotHead
      end) >>|
  (fun ack -> Chain_json_processor.client_ack_to_json_client_ack ack |> Yojson.Basic.to_string |> Writer.write_line w)

let mk ~ipv4:ipv4 ~port:port =
  let inet_addr = Tcp.Bind_to_address.Address (Unix.Inet_addr.of_string ipv4) in
  let port_addr = Tcp.Bind_to_port.On_port port in
  let where_to_listen = Tcp.Where_to_listen.bind_to inet_addr port_addr in
  Tcp.Server.create
    ~on_handler_error:`Ignore
      where_to_listen
      handler

let rm server = Tcp.Server.close server
