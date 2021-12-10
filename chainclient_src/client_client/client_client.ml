open Async
open Core

type result = UpdateOk | QueryOk of int | QueryNotFound | Disconnect
type internal_result = External of result | TryAgain

let handler req _sock r w =
  Client_json_processor.mk_req req |> Yojson.Basic.to_string |> Writer.write_line w;
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
    match Buffer.contents buf |> Yojson.Basic.from_string |> Client_json_processor.process_ack with
    | Found (d) -> begin
      Async.Print.printf " Successfully contacted tail and submitted query. Value is %d.\n>> " d;
      External (QueryOk (d))
    end
    | NotFound -> begin
      Async.Print.printf " Successfully contacted tail and submitted query. Value not found.\n>> ";
      External (QueryNotFound)
    end
    | Ok -> begin
      Async.Print.printf " Successfully contacted head and submitted update.\n>> ";
      External (UpdateOk)
    end
    | NotHead (ipv4, port) -> begin
      Async.Print.printf " Successfully contacted a node but node wasn't head, got new head. Try again.\n>> ";
      Client_config.add_head ~ipv4:ipv4 ~port:port;
      TryAgain
    end
    | NotTail (ipv4, port) -> begin
      Async.Print.printf " Successfully contacted a node but node wasn't tail, got new tail. Try again.\n>> ";
      Client_config.add_tail ~ipv4:ipv4 ~port:port;
      TryAgain
    end)

let connect_once ~is_update:is_update ~req:req ~ipv4:ipv4 ~port:port = 
  let str = if is_update then "head" else "tail" in
  let inet = Core.Unix.Inet_addr.of_string ipv4 in 
  let inet_addr = Async_unix.Socket.Address.Inet.create inet ~port:port in
  (*Async.Print.printf "Attempting to send request to %s node %s:%d." str ipv4 port;*)
  let where_to_connect = Tcp.Where_to_connect.of_inet_address inet_addr in
  Monitor.try_with
    (fun () -> Async_unix.Tcp.with_connection
      where_to_connect
      (handler req)) >>|
  (function
    | Ok (res) -> res
    | Error _e -> begin 
      (*Async.Print.printf " Exn %s" (Exn.to_string e);*)
      Async.Print.printf " The contacted %s is down. Finding next %s.\n>> " str str;
      if is_update then Client_config.kill_head () else Client_config.kill_tail ();
      TryAgain
    end)

let pre_connect ~req:req =
  match req with 
  | Client_data.Update (_, _) -> begin 
    match Client_config.get_head () with
    | None -> External (Disconnect) |> return
    | Some (ipv4, port) -> begin
      Async.Print.printf "Attempting to send update request to %s:%d." ipv4 port;
      connect_once ~is_update:true ~req:req ~ipv4:ipv4 ~port:port
    end
  end
  | Client_data.Query (_) -> begin
    match Client_config.get_tail () with
    | None -> External (Disconnect) |> return
    | Some (ipv4, port) -> begin
      Async.Print.printf "Attempting to send query request to %s:%d." ipv4 port;
      connect_once ~is_update:false ~req:req ~ipv4:ipv4 ~port:port
    end
  end

let send_request ~req:req =
  let rec try_to_send () =
    (pre_connect ~req:req) >>=
    (function
      | External res' -> return res'
      | TryAgain -> try_to_send ())
  in
  try_to_send ()
