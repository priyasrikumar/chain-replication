open Core

let max_port = 65535

let validate_ipv4 ipv4 = 
	try 
		ignore (Unix.Inet_addr.of_string ipv4);
		true 
	with _ -> false 

let validate_port port =
	if port < 0 || port > max_port then false
	else true

let parse_addr addr = 
	match String.split addr ~on:':' with
	| inet :: port :: [] -> begin
		try
			ignore (Unix.Inet_addr.of_string inet);
			let port_i = Int.of_string port in
			if port_i < 0 || port_i > max_port then None
			else Some ((inet,port_i))
		with Failure _ -> None
	end
	| _ -> None

let parse_beliefs beliefs =
	List.filter_map
		beliefs
		~f:parse_addr
