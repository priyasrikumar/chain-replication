open Core

type res = Succ | Pred | Neither

type node = {
  ipv4 : string;
  port : int;
  succ : node Option.t ref;
  pred : node Option.t ref;
  mutable dead : bool;
}

let me : node ref = ref 
  {
   ipv4 = "0.0.0.0";
   port = 0;
   pred = ref None;
   succ = ref None;
   dead = true;
  }

let curr_head : node Option.t ref = ref None
let curr_tail : node Option.t ref = ref None

let is_head () = Option.is_none !((!me).pred)
let is_tail () = Option.is_none !((!me).succ)

module SIPair = Tuple.Hashable_t (String) (Int)
module Tbl = SIPair.Table 

let nodes = Tbl.create ()

let _start_chain ~ipv4:ipv4 ~port:port =
  let node = { 
      ipv4 = ipv4;
      port = port;
      succ = ref (None);
      pred = ref (None);
      dead = false;
    }
  in
  curr_head := Some (node);
  curr_tail := Some (node)

let join_chain () =
  me := Option.value_map !curr_head ~default:!me ~f:ident

let add_proc ~ipv4:ipv4 ~port:port =
  if Option.is_none !curr_head then begin
    let node = { 
      ipv4 = ipv4;
      port = port;
      succ = ref (None);
      pred = ref (None);
      dead = false;
    }
    in
    curr_head := Some (node);
    curr_tail := Some (node);
    Tbl.update nodes (ipv4,port) ~f:(fun _ -> node)
  end else begin 
    let new_head = { 
        ipv4 = ipv4;
        port = port;
        succ = ref (!curr_head);
        pred = ref (None);
        dead = false;
      }
    in
    (Option.value_exn !curr_head).pred := Some (new_head);
    curr_head := Some (new_head);
    Tbl.update nodes (ipv4,port) ~f:(fun _ -> new_head)
  end

let get_succ () =
  Option.value_map !((!me).succ) ~default:None
    ~f:(fun node -> if node.dead then None else Some ((node.ipv4, node.port)))
let get_succs () =
  let succs = Deque.create () in
  let ptr = ref (!me) in 
  while Option.is_some !(!ptr.succ) do
    ptr := Option.value_exn !(!ptr.succ);
    if !ptr.dead |> not then begin Deque.enqueue_back succs (!ptr.ipv4,!ptr.port) end
  done;
  Deque.to_list succs

let get_pred () =
  Option.value_map !((!me).pred) ~default:None
    ~f:(fun node -> if node.dead then None else Some ((node.ipv4, node.port)))
let get_preds () =
  let preds = Deque.create () in
  let ptr = ref (!me) in 
  while Option.is_some !(!ptr.pred) do
    ptr := Option.value_exn !(!ptr.pred);
    if !ptr.dead |> not then begin Deque.enqueue_back preds (!ptr.ipv4,!ptr.port) end
  done;
  Deque.to_list preds

let get_head () =
  while Option.value_map !curr_head ~default:false ~f:(fun node -> node.dead) do
    curr_head := !((Option.value_exn !curr_head).succ)
  done;
  match !curr_head with
  | None -> failwith "Should be impossible, there is always a head."
  | Some node -> Some ((node.ipv4,node.port))

let get_tail () =
  while Option.value_map !curr_tail ~default:false ~f:(fun node -> node.dead) do
    curr_tail := !((Option.value_exn !curr_tail).pred)
  done;
  match !curr_tail with
  | None -> failwith "Should be impossible, there is always a tail."
  | Some node -> Some ((node.ipv4,node.port))

let kill_succ () = Option.iter !((!me).succ) ~f:(fun node -> node.dead <- true)
let kill_pred () = Option.iter !((!me).pred) ~f:(fun node -> node.dead <- true)

let find_next_succ () =
  while Option.value_map !((!me).succ) ~default:false ~f:(fun node -> node.dead) do
    (!me).succ := !((Option.value_exn !((!me).succ)).succ)
  done

let find_next_pred () =
  while Option.value_map !((!me).pred) ~default:false ~f:(fun node -> node.dead) do
    (!me).pred := !((Option.value_exn !((!me).pred)).pred)
  done

let kill_node ~ipv4:ipv4 ~port:port =
  Tbl.find_and_call nodes (ipv4,port)
    ~if_found:(fun node ->
      node.dead <- true;
      if Option.value_map !(!me.pred) ~default:false ~f:(fun node -> String.equal node.ipv4 ipv4 && Int.equal node.port port) then begin
        find_next_pred (); Pred
      end else if Option.value_map !(!me.succ) ~default:false ~f:(fun node -> String.equal node.ipv4 ipv4 && Int.equal node.port port) then begin
        find_next_succ (); Succ
      end else Neither)
    ~if_not_found:(fun _ -> Neither)

let recv_msg ~ipv4:ipv4 ~port:_port =
  while Option.value_map !((!me).pred) ~default:false ~f:(fun node -> String.(node.ipv4 <> ipv4) (*|| node.port <> port*)) do
    (Option.value_exn !((!me).pred)).dead <- true;
    (!me).pred := !((Option.value_exn !((!me).pred)).pred)
  done
