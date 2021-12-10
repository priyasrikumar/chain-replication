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
  (fun () -> 
    Async.Print.printf "Got a join request from %s. "
      (Async_unix.Socket.Address.Inet.to_string addr);
    if Chain_config.is_head () then begin 
      Async.Print.printf "Server is head, sending log to new head. ";
      let (ipv4,port) =
        Buffer.contents buf |>
        Yojson.Basic.from_string |> 
        Chain_json_processor.add_proc_req_json_to_add_proc_req |>
        Add_proc_req.get_add_proc
      in
      Chain_log.add_proc ~ipv4:ipv4 ~port:port;
      Chain_config.add_proc ~ipv4:ipv4 ~port:port;
      Async.Print.printf "New head : %s:%d.\n>> " ipv4 port;
      Add_proc_ack.Ok
    end else begin
      Async.Print.printf "Server is not head, sending current head to server wishing to join\n>> ";
      Add_proc_ack.NotHead
    end) >>|
  (fun ack -> Chain_json_processor.add_proc_ack_to_json_add_proc_ack ack |> Yojson.Basic.to_string |> Writer.write_line w)

let mk ~ipv4:ipv4 ~port:port =
  let inet_addr = Tcp.Bind_to_address.Address (Unix.Inet_addr.of_string ipv4) in
  let port_addr = Tcp.Bind_to_port.On_port port in
  let where_to_listen = Tcp.Where_to_listen.bind_to inet_addr port_addr in
  Tcp.Server.create
    ~on_handler_error:`Ignore
      where_to_listen
      handler

let rm server = Tcp.Server.close server
