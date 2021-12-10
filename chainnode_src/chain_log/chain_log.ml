open Async
open Core

type entry_typ = ClientUpdate | AddProc 

type log_entry = {
	str: string;
	num: int;
	typ: entry_typ;
	uid: int * int;
}

let equal l1 l2 =
	(Int.equal (l1.uid |> fst) (l2.uid |> fst)) &&
	(Int.equal (l1.uid |> snd) (l2.uid |> snd)) &&
	(String.equal l1.str l2.str) &&
	(Int.equal l1.num l2.num) &&
	(match l1.typ, l2.typ with
		| ClientUpdate, ClientUpdate | AddProc, AddProc -> true
		| _ -> false)

let sent : log_entry Deque.t = Deque.create ()
let pend : log_entry Deque.t = Deque.create ()

let uid_tbl : (int, int) Hashtbl.t = Hashtbl.create (module Int)

let next_uid ipv4 port =
	let ip_split = String.split ipv4 ~on:'.' in
	let f = (fun i acc curr -> acc + Int.shift_left (Int.of_string curr) (((3 - i) * 8) + 16)) in
	let ip_int = (List.foldi ip_split ~init:0 ~f:f) + port in 
	let cnt = Hashtbl.find_or_add uid_tbl ip_int ~default:(fun _ -> 1) in
	Hashtbl.update uid_tbl ip_int ~f:(fun _ -> cnt + 1);
	(ip_int, cnt)

let size () = Deque.length sent + Deque.length pend 

let has_new = Bvar.create ()
let stop_broadcast () = Bvar.broadcast has_new false

let client_update ~ipv4:ipv4 ~port:port ~var:var ~num:num =
	let log_entry = { str = var; num = num; typ = ClientUpdate; uid = next_uid ipv4 port} in
	Deque.enqueue_back pend log_entry;
	if Chain_config.is_tail () then Database.add ~key:var ~num:num;
	Bvar.broadcast has_new true

let add_proc ~ipv4:ipv4 ~port:port =
	let log_entry = { str = ipv4; num = port; typ = AddProc; uid = next_uid ipv4 port } in
	Deque.enqueue_back pend log_entry;
	Bvar.broadcast has_new true

let to_send () =
	Deque.to_list pend (*|> make_json_log*)

let all () =
	List.append (Deque.to_list sent) (Deque.to_list pend)

let commit_send () =
	while Deque.is_empty pend |> not do
		Deque.dequeue_front_exn pend |> Deque.enqueue_back sent
	done

let receive_log ?(not_new_head=true) new_log =
	(*let new_log = parse_json_log new_json in *)
	let cur_log = List.append (Deque.to_list sent) (Deque.to_list pend) in
	let rec merge l1 l2 =
		match l1, l2 with
		| hd1 :: tl1, hd2 :: tl2 when equal hd1 hd2 -> merge tl1 tl2
		| [], _->
			List.iter l2
				~f:(fun node ->
							begin
								match node.typ with
								| AddProc -> begin Chain_config.add_proc ~ipv4:node.str ~port:node.num end
								| ClientUpdate -> begin if Chain_config.is_tail () then Database.add ~key:node.str ~num:node.num end
							end;
							Deque.enqueue_back pend node);
			if not_new_head then Bvar.broadcast has_new true;
			true
		| _ -> false
	in  
	merge cur_log new_log

let commit_log () =
	let cur_log = List.append (Deque.to_list sent) (Deque.to_list pend) in
	List.iter cur_log
		~f:(fun node ->
			match node.typ with
			| ClientUpdate -> Database.add ~key:node.str ~num:node.num;
			| _ -> ())

let reset_sent () =
	while Deque.is_empty sent |> not do
		Deque.dequeue_back_exn sent |> Deque.enqueue_front pend
	done

let reset () =
	Deque.clear sent; Deque.clear pend
