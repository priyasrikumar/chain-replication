open Async
open Core

let stop = ref false 
let timeout = 3

let handler_send _sock r w =
	let req = `Assoc ([("msg_typ", `String ("Log")); ("contents", Chain_log.to_send () |> Chain_json_processor.make_json_log)]) in
	Yojson.Basic.to_string req |> Writer.write_line w;
	let buf = Buffer.create 5 in
	let rec read_line () =
    Reader.read_char r >>=
    (function
      | `Ok ('\n') -> return ()
      | `Ok (c) -> Buffer.add_char buf c |> read_line
      | `Eof -> return ())
  in
	read_line () >>|
	(fun () -> Buffer.contents buf |> Yojson.Basic.from_string |> Chain_json_processor.json_chain_ack_to_chain_ack)

let connect_once_send _is_opt () =
	match Chain_config.get_succ () with
	| None -> return ()
	| Some ((ipv4, port)) ->
		let inet = Core.Unix.Inet_addr.of_string ipv4 in 
		let inet_addr = Async_unix.Socket.Address.Inet.create inet ~port:port in
		Async.Print.printf "Attempting to send log to successor node %s:%d." ipv4 port;
		let where_to_connect = Tcp.Where_to_connect.of_inet_address inet_addr in
		Monitor.try_with
			(fun () -> Async_unix.Tcp.with_connection
				where_to_connect
				handler_send) >>|
		(function
			| Ok _ -> begin
				(*if is_opt then Chain_log.commit_send ();*)
				Async.Print.printf " Successfully contacted successor and sent log.\n>> "
			end
			| Error _ -> begin 
				Async.Print.printf " Successor is down. Finding next successor.";
				Chain_config.kill_succ ();
				Chain_config.find_next_succ ();
				(*if is_opt then Chain_log.reset_sent ();*)
				if Chain_config.is_tail () then begin
					Async.Print.printf " Node became the new tail, committing log.";
					Chain_log.commit_log ();
					(*if is_opt then Chain_log.commit_send ()*)
				end;
				Async.Print.printf "\n>> "
			end)

let handler_checkin _sock r w =
	let req = `Assoc ([("msg_typ", `String ("Checkin")); ("contents", Chain_json_processor.checkin_req_to_json_checkin_req Checkin_req.checkin)]) in
	Yojson.Basic.to_string req |> Writer.write_line w;
	let buf = Buffer.create 5 in
	let rec read_line () =
    Reader.read_char r >>=
    (function
      | `Ok ('\n') -> return ()
      | `Ok (c) -> Buffer.add_char buf c |> read_line
      | `Eof -> return ())
  in
	read_line () >>|
	(fun () -> Buffer.contents buf |> Yojson.Basic.from_string |> Chain_json_processor.json_chain_ack_to_chain_ack)

let connect_once_checkin _is_opt ~contact_predeccesor:mode () =
	let str = if mode then "predeccesor" else "successor" in
	let contact = if mode then Chain_config.get_preds () else Chain_config.get_succs () in
	if List.is_empty contact then begin Async.Print.printf "No %ss checkin because no %ss found.\n>> " str str; return () end
	else
		Deferred.List.iter ~how:(`Parallel) contact
			~f:(fun (ipv4,port) -> 
					let inet = Core.Unix.Inet_addr.of_string ipv4 in 
					let inet_addr = Async_unix.Socket.Address.Inet.create inet ~port:port in
					Async.Print.printf "Attempting to check in with %s node %s:%d." str ipv4 port;
					let where_to_connect = Tcp.Where_to_connect.of_inet_address inet_addr in
					Monitor.try_with
						(fun () -> Async_unix.Tcp.with_connection
							where_to_connect
							handler_checkin) >>|
					(function
						| Ok _ -> begin
							Async.Print.printf " Successfully contacted %s.\n>> " str
						end
						| Error _ -> begin
							Async.Print.printf " Marking %s as down.\n>> " str;
							match Chain_config.kill_node ~ipv4:ipv4 ~port:port with
							| Chain_config.Succ -> () (*begin
								if is_opt then Chain_log.reset_sent ()
							end*)
							| _ -> ()
						end))

let start ?(is_opt=false) () =
	let rec loop1 () =
		Bvar.wait Chain_log.has_new >>=
		(fun cond ->
			if cond then connect_once_send is_opt () >>= loop1 
			else return ())
	in
	let rec loop2 () =
    if !stop then return ()
    else
      after (Time.Span.of_int_sec timeout) >>=
      connect_once_checkin is_opt ~contact_predeccesor:true >>=
      fun () -> after (Time.Span.of_int_sec timeout) >>=
      connect_once_checkin is_opt ~contact_predeccesor:false >>=
      loop2
  in
  don't_wait_for (loop1 ()); 
  don't_wait_for (loop2 ())

let stop () = Chain_log.stop_broadcast (); stop := true 
