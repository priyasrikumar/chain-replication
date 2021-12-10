open Async
open Core

open Test_config_parser

let handler tw _sock _r w = Writer.write_line w tw |> return

let connect_once ~to_write:tw ~ipv4:ipv4 ~port:port = 
  let inet = Core.Unix.Inet_addr.of_string ipv4 in 
  let inet_addr = Async_unix.Socket.Address.Inet.create inet ~port:port in
  let where_to_connect = Tcp.Where_to_connect.of_inet_address inet_addr in
  Monitor.try_with
    (fun () -> Async_unix.Tcp.with_connection
      where_to_connect
      (handler tw)) >>|
  (function
    | Ok _ -> begin
      Async.Print.printf " Successfully reached %s:%d.\n" ipv4 port
    end
    | Error e -> Async.Print.printf " Exn %s\n" (Exn.to_string e))

let start = "$\n"
let kill = "#\n"

let go_with_mininet ~data:{server_addrs = sad; client_addrs = cad; backup_addrs = bad; failures = f; duration = d } = 
  after (Time.Span.create ~sec:5 ()) >>=
  (fun () -> Deferred.List.iter sad ~f:(fun (ipv4,port) -> connect_once ~to_write:start ~ipv4:ipv4 ~port:port)) >>=
  (fun () -> Deferred.List.iter cad ~f:(fun (ipv4,port) -> connect_once ~to_write:start ~ipv4:ipv4 ~port:port)) >>=
  (fun () -> 
    let rec test t f sad bad bad2 () =
      match f with 
      | [] -> after (Time.Span.create ~sec:(d - t) ()) >>| (fun _ -> (sad,bad2))
      | hd :: tl ->
        after (Time.Span.create ~sec:hd ()) >>=
        (fun () ->
          let idx = Random.int (List.length sad) in
          let (ipv4,port) = List.nth_exn sad idx in
          let (ipv4',port') = List.hd_exn bad in
          let sad' = List.filter sad ~f:(fun (ipv4'',port'') -> String.(ipv4'' <> ipv4) && port'' <> port) in
          let bad' = List.tl_exn bad in
          let bad2 = (ipv4',port') :: bad2 in 
          connect_once ~to_write:kill ~ipv4:ipv4 ~port:port >>=
          (fun _ -> connect_once ~to_write:start ~ipv4:ipv4' ~port:port') >>=
          test (t + hd) tl sad' bad' bad2)
    in
    test 0 f sad bad [] ()) >>=
  (fun (sad,bad) -> after (Time.Span.create ~sec:5 ()) >>= (fun () -> return (sad,bad))) >>=
  (fun (sad,bad) ->
    Deferred.List.iter sad ~f:(fun (ipv4,port) -> connect_once ~to_write:kill ~ipv4:ipv4 ~port:port) >>=
    (fun _ -> Deferred.List.iter bad ~f:(fun (ipv4,port) -> connect_once ~to_write:kill ~ipv4:ipv4 ~port:port)))

open Process_starter

let go_with_procs ~server_prog:sp ~data:{ server_addrs = sad; client_addrs = cad; backup_addrs = bad; backup_args = bar; failures = f; duration = d} =
  after (Time.Span.create ~sec:5 ()) >>=
  (fun () -> Deferred.List.iter sad ~f:(fun (ipv4,port) -> connect_once ~to_write:start ~ipv4:ipv4 ~port:port)) >>=
  (fun () -> Deferred.List.iter cad ~f:(fun (ipv4,port) -> connect_once ~to_write:start ~ipv4:ipv4 ~port:port)) >>=
  (fun () -> 
    let rec test t f sad bad bar () =
      match f with 
      | [] -> after (Time.Span.create ~sec:(d - t) ())
      | hd :: tl ->
        after (Time.Span.create ~sec:hd ()) >>=
        (fun () ->
          let idx = Random.int (List.length sad) in
          let (ipv4,port) = List.nth_exn sad idx in
          let (ipv4',port') = List.hd_exn bad in
          let server_addr = List.hd_exn bar in
          let sad' = List.filter sad ~f:(fun (ipv4'',port'') -> String.(ipv4'' <> ipv4) && port'' <> port) in
          let bad' = List.tl_exn bad in
          let bar' = List.tl_exn bar in
          connect_once ~to_write:kill ~ipv4:ipv4 ~port:port >>=
          (fun () -> Process.create_exn ~prog:sp ~args:server_addr ()) >>=
          (fun _ -> connect_once ~to_write:start ~ipv4:ipv4' ~port:port') >>=
          test (t + hd) tl sad' bad' bar')
    in
    test 0 f sad bad bar ()) >>=
  (fun () -> Deferred.List.iter sad ~f:(fun (ipv4,port) -> connect_once ~to_write:kill ~ipv4:ipv4 ~port:port)) >>=
  (fun () -> Deferred.List.iter bad ~f:(fun (ipv4,port) -> connect_once ~to_write:kill ~ipv4:ipv4 ~port:port)) >>=
  (fun () -> Async.Print.printf "Testing finished, see logs for output." |> return)
