open Async
open Core

let iloop () =
	let stdin = Reader.stdin |> Lazy.force in
	let rec loop () =
		Async.Print.printf ">> ";
		Reader.read_line stdin >>|
		(function
			| `Ok line -> String.strip line
			| `Eof -> "quit") >>=
		(function
			| "quit" -> return ()
			| s when (String.get s 0 |> Char.equal 'u') -> begin
				match String.split (String.drop_prefix s 1 |> String.strip) ~on:' ' with
				| [var; num] -> begin
					let req = Client_data.mk_update ~var:var ~num:(Int.of_string num) in
					Client_client.send_request ~req:req >>=
					(fun ack -> 
						Client_client.(match ack with 
						| UpdateOk -> begin
							Async.Print.printf "Update request was accepted at head.\n" |> loop 
						end 
						| Disconnect -> begin
							Async.Print.printf "Lost track of all chain nodes, exiting program.\n" |> return
						end 
						| _ -> begin
							Async.Print.printf "Unexpected response received from chain server, status of request unknown.\n" |> return
						end))
				end
				| _ -> begin
					Async.Print.printf "Bad input: Cannot parse update request.\n" |> loop 
				end				
			end
			| s when (String.get s 0 |> Char.equal 'q') -> begin
				match String.split (String.drop_prefix s 1 |> String.strip) ~on:' ' with
				| [var] -> begin
					let req = Client_data.mk_query ~var:var in
					Client_client.send_request ~req:req >>=
					(fun ack ->
						Client_client.(match ack with 
						| QueryOk (i) -> begin
							Async.Print.printf "Variable %s found in database with value %d.\n" var i |> loop 
						end 
						| QueryNotFound -> begin
							Async.Print.printf "Variable %s not found in database.\n" var |> loop 
						end 
						| Disconnect -> begin
							Async.Print.printf "Lost track of all chain nodes, exiting program.\n" |> return
						end 
						| _ -> begin
							Async.Print.printf "Unexpected response received from chain server, status of request unknown.\n" |> return
						end))
				end
				| _ -> begin
					Async.Print.printf "Bad input: Cannot parse update request.\n" |> loop 
				end
			end 
			| _ -> begin
				Async.Print.printf "Bad input: See spec for valid input formats.\n" |> loop
			end)
	in
	loop ()
