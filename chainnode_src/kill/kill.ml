open Async
open Core

let stop = Bvar.create ()

let handler _addr r _w =
  let buf = Buffer.create 5 in
  let rec read_line () =
    Reader.read_char r >>=
    (function
      | `Ok ('\n') -> return ()
      | `Ok (c) -> Buffer.add_char buf c |> read_line
      | `Eof -> return ())
  in
  read_line () >>|
  (fun () -> Buffer.contents buf |> String.equal "#") >>|
  (fun cond -> if cond then begin Reader.Read_result.return "quit" |> Bvar.broadcast stop end)

let mk ~ipv4:ipv4 ~port:port =
  let inet_addr = Tcp.Bind_to_address.Address (Unix.Inet_addr.of_string ipv4) in
  let port_addr = Tcp.Bind_to_port.On_port port in
  let where_to_listen = Tcp.Where_to_listen.bind_to inet_addr port_addr in
  Tcp.Server.create
    ~on_handler_error:`Ignore
      where_to_listen
      handler

let rm server = Tcp.Server.close server

let iloop ~ipv4:ipv4 ~port:port ~is_init:is_init =
  if is_init then Async.Print.printf ">> ";
  let stdin = Reader.stdin |> Lazy.force in
  let rec loop () =
    Deferred.any [Reader.read_line stdin; Bvar.wait stop] >>|
    (function
      | `Ok line -> String.strip line
      | `Eof -> "quit") >>=
    (function
      | "quit" -> return ()
      | _ -> loop ())
  in
  mk ~ipv4:ipv4 ~port:port >>= 
  (fun server -> loop () >>= (fun () -> rm server))
