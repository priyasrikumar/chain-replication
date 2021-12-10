(* set the ipv4 and port of this node *)
(*val set_ipv4 : string -> unit*)
(*val set_port : int -> unit*)
type res = Succ | Pred | Neither

(* return true if node believes it is the head *)
val is_head : unit -> bool
(* return true if node believes it is the tail *)
val is_tail : unit -> bool 

(** 
  * start_chain allows for the starting of a chain
  * by initializing a chain with the current processor
  *)
(*val start_chain : ipv4:string -> port:int -> unit*)

(** 
  * join the chain as the head of the config, call this
  * after estabilishing chain as your position as head
  * may change depending on the scenario
  *)
val join_chain : unit -> unit

(** 
  * add_proc allows for the update of configuration belief set 
  * by adding a new processor to the configuration
  *)
val add_proc : ipv4:string -> port:int -> unit

(* get the successor of this node, None if it doesn't exist *)
val get_succ : unit -> (string * int) Core.Option.t
(* get all successors of this node, [] if none *)
val get_succs : unit -> (string * int) list
(* get the predeccessor of this node, None if it doesn't exist *)
val get_pred : unit -> (string * int) Core.Option.t
(* get all predeccessors of this node, [] if none *)
val get_preds : unit -> (string * int) list
(* get the head of this config, None if it doesn't exist *)
val get_head : unit -> (string * int) Core.Option.t
(* get the tail of this node, None if it doesn't exist *)
val get_tail : unit -> (string * int) Core.Option.t
(* mark the sucessor as crashed in the config *)
val kill_succ : unit -> unit 
(* mark the predecessor as crashed in the config *)
val kill_pred : unit -> unit 
(* mark a specific node as crashed *)
val kill_node : ipv4:string -> port:int -> res
(* find the next successor in the config *)
val find_next_succ : unit -> unit 
(* find the next predecessor in the config *)
val find_next_pred : unit -> unit 

(**
  * recv_msg will kill predecessors if it differes from the current predecessor 
  * should only be called if an entire log is accepted (prefix rule)
  *)
val recv_msg : ipv4:string -> port:int -> unit 
