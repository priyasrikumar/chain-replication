open Async
open Core

type result = Ok | NotHead of string * int | Fail

let handler (ipv4,port) _sock r w =
	let req = Add_proc_req.mk_add_proc ~ipv4:ipv4 ~port:port in
	Chain_json_processor.add_proc_req_to_add_proc_req_json req |> Yojson.Basic.to_string |> Writer.write_line w;
	let buf = Buffer.create 2000 in
	let rec read_line () =
    Reader.read_char r >>=
    (function
      | `Ok ('\n') -> return ()
      | `Ok (c) -> Buffer.add_char buf c |> read_line
      | `Eof -> return ())
  in
  read_line () >>|
	(fun () ->
		let open Yojson.Basic.Util in
		let ack = Buffer.contents buf |> Yojson.Basic.from_string in
		try
			let typ = ack |> member "type" |> to_string in
			if String.equal typ "Ok" then
				let ok = ack |> member "data" |> Chain_json_processor.parse_json_log |> Chain_log.receive_log ~not_new_head:false in
				if ok then begin
					Async.Print.printf "Successfully joined chain as head.\n>> ";
					Chain_config.join_chain ();
					Ok 
				end else begin
					Async.Print.printf "Contacted head but could not join chain due to log mismatch.\n>> ";
					Fail
				end 
			else begin 
				let ipv4 = ack |> member "data" |> member "ipv4" |> to_string in
				let port = ack |> member "data" |> member "port" |> to_int in
				Async.Print.printf "Could not join head as contacted node believes head is at %s:%d.\n>> "
					ipv4 port;
				NotHead (ipv4,port)
			end
		with _ -> Chain_json_processor.raise_invalid_arg "Bad entry" ack)

let connect (my_ipv4,my_port) (ipv4,port) =
	let inet = Core.Unix.Inet_addr.of_string ipv4 in
	let inet_addr = Async_unix.Socket.Address.Inet.create inet ~port:port in
	let where_to_connect = Tcp.Where_to_connect.of_inet_address inet_addr in
	Async.Print.printf "Attempting to join chain by contacting %s:%d. " ipv4 port;
	Monitor.try_with
		(fun () -> Async_unix.Tcp.with_connection
			where_to_connect
			(handler (my_ipv4,my_port))) >>|
		(function
			| Ok x -> x
			| Error _ -> Fail)

let attempt_join ~ipv4:ipv4 ~port:port ~potential_heads:ls =
	let rec iter ls =
		match ls with
		| [] -> return false
		| hd :: tl -> begin 
			connect (ipv4,port) hd >>=
			(fun res ->
				match res with
				| Ok -> return true
				| NotHead ((ipv4,port)) -> iter ((ipv4,port+1) :: tl)
				| Fail -> iter tl)
		end
	in
	Async.Print.printf ">> ";
	iter ls >>|
	(fun cond ->
		if cond then begin
			true
		end else begin
			Async.Print.printf "Failed to join chain as all contacted nodes refused join request.\n";
			false
		end)
