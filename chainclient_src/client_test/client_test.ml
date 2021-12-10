open Async
open Core

type finish = Good | Bad of string

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

let run ~seed:_seed ~chain_length:cl ~duration:d ~l_bound:lb ~r_bound:rb ~ratio:r ~ipv4:ipv4 ~port:port =
	(*(if seed = 0 then begin Random.self_init () end else begin Random.init seed end);*)
	let objs = List.range ~stride:1 ~start:`inclusive ~stop:`inclusive lb rb |> List.map ~f:(fun i -> (Int.to_string i,())) |> Hashtbl.of_alist_exn (module String) in
	let cond = Mvar.create () in
	let record = Mvar.create () in
	let tx_updates = Queue.create () in 
	let tx_queries = Queue.create () in
	let tx_update = ref 0 in
	let tx_query = ref 0 in
	let stat () =
		Queue.enqueue tx_updates !tx_update; 
		Queue.enqueue tx_queries !tx_query;
		tx_update := 0;
		tx_query := 0
	in
	let rec f () =
		match Mvar.take_now cond, Mvar.take_now record with
		| Some true, _ -> begin stat (); return Good end
		| None, None -> 
			if Float.((Random.float 1.) >= (1. - r)) then
				let var, _ = Hashtbl.choose_exn objs in
				let num = Random.bits () in 
				let req_u = Client_data.mk_update ~var:var ~num:num in
				let req_q = Client_data.mk_query ~var:var in
				let rec keep_trying () =
					Client_client.send_request ~req:req_q >>=
					(fun ack -> Client_client.(
						match ack with 
						| QueryOk (i) when i = num -> begin tx_update := !tx_update + 1; f () end
						| QueryOk (_) | QueryNotFound -> keep_trying ()
						| UpdateOk -> return (Bad "Got a update ack for a query request.")
						| Disconnect -> return (Bad "Disconnected from server when expecting a result to a query request.")))
				in
				Client_client.send_request ~req:req_u >>=
				(fun ack -> Client_client.(
					match ack with
					| UpdateOk ->
						let delay = Time.Span.create ~ms:(50 + (20 * (cl - 1)) + cl + 1) () in
						after delay >>= keep_trying
					| QueryOk (_) | QueryNotFound -> return (Bad "Got a query ack for a update request.")
					| Disconnect -> return (Bad "Disconnected from server when expecting a result to a query request.")))
			else
				let var, _ = Hashtbl.choose_exn objs in
				let req = Client_data.mk_query ~var:var in
				Client_client.send_request ~req:req >>=
				(fun ack -> Client_client.(
					match ack with 
					| QueryOk (_) | QueryNotFound -> begin
						tx_query := !tx_query + 1; f ()
					end
					| UpdateOk -> return (Bad "Got a update ack for a query request.")
					| Disconnect -> return (Bad "Disconnected from server when expecting a result to a query request.")))
		| _, Some true -> begin stat () |> f end 
		| _, _ -> f () 
	in
	let stop = Time.Span.create ~sec:d () in
	don't_wait_for (after stop >>= (fun () -> Mvar.put cond true));
	don't_wait_for (after (Time.Span.create ~sec:1 ()) >>= (fun () -> Mvar.put record true));
	with_timeout (Time.Span.create ~sec:(d+2) ())
		(f ()) >>=
	(function
		| `Result (fin) -> return fin 
		| `Timeout -> return (Bad "Timed out while waiting for a response from the server.")) >>=
	(fun fin ->
		Writer.with_file (Format.sprintf "%s.%d.out" ipv4 port)
			~f:(fun w ->
				(match fin with Good -> Writer.write_line w "Good" | Bad s -> Writer.write_line w (Format.sprintf "Bad: %s" s));
				let buf = Buffer.create (((d + 1) * 2) + 16 + 17) in
				Buffer.add_string buf "Update througput";
				Queue.iter tx_updates ~f:(fun i -> ":"^Int.to_string i |> Buffer.add_string buf);
				Buffer.add_string buf "\nQuery througput";
				Queue.iter tx_queries ~f:(fun i -> ":"^Int.to_string i |> Buffer.add_string buf);
				Buffer.contents buf |> Writer.write_line w;
				return ()))

let test ~seed:seed ~chain_length:cl ~wait:w ~duration:d ~l_bound:lb ~r_bound:rb ~ratio:r ~ipv4:ipv4 ~port:port =
	if w then begin
		mk ~ipv4:ipv4 ~port:port >>=
		(fun server -> Bvar.wait stop >>=
			(function
			| `Quit -> rm server
			| `Start -> rm server >>= (fun () -> run ~seed:seed ~chain_length:cl ~duration:d ~l_bound:lb ~r_bound:rb ~ratio:r ~ipv4:ipv4 ~port:port)))
	end else run ~seed:seed ~chain_length:cl ~duration:d ~l_bound:lb ~r_bound:rb ~ratio:r ~ipv4:ipv4 ~port:port
	
