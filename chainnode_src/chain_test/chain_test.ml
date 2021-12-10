open Async

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
  (fun cond -> if cond then Bvar.broadcast stop `Quit else Bvar.broadcast stop `Start)

let mk ~ipv4:ipv4 ~port:port =
  let inet_addr = Tcp.Bind_to_address.Address (Unix.Inet_addr.of_string ipv4) in
  let port_addr = Tcp.Bind_to_port.On_port port in
  let where_to_listen = Tcp.Where_to_listen.bind_to inet_addr port_addr in
  Tcp.Server.create
    ~on_handler_error:`Ignore
      where_to_listen
      handler

let rm server = Tcp.Server.close server

let test ~wait:wait ~ipv4:ipv4 ~port:port =
  if wait then
    mk ~ipv4:ipv4 ~port:port >>=
    (fun server -> Bvar.wait stop >>=
      (function
      | `Quit -> rm server >>= (fun () -> return false)
      | `Start -> rm server >>= (fun () -> return true)))
  else return true 
