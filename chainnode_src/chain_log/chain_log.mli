(* a log entry is either a ClientUpdate or a AddProc *)
type entry_typ = ClientUpdate | AddProc 

(* a log entry is a (string,int pair) along with its type and unique id *)
type log_entry = {
  str: string;
  num: int;
  typ: entry_typ;
  uid: int * int;
}

(* size of log *)
val size : unit -> int

(* notify when a new entry is added to the log, this way log entries can be sent down the chain *)
val has_new : (bool, Core.read_write) Async.Bvar.t
(* stop the broadcast upon exit from program, cleanup code *)
val stop_broadcast : unit -> unit

(**
  * process a client update from some client node
  * should only be called if node believes its the head
  *)
val client_update : ipv4:string -> port:int -> var:string -> num:int -> unit

(**
  * process an add proc from some chain node requesting to join chain
  * called if node believes itself to be the head
  *)
val add_proc : ipv4:string -> port:int -> unit

(* obtain json to send to successor node *)
val to_send : unit -> log_entry list
(* obtain all of the log *)
val all : unit -> log_entry list
(* remove all to_send messages, only call if next node has confirmed it has received the to_send *)
val commit_send : unit -> unit

(**
  * receive a log from the preivous node
  * if the current log is not a prefix of the received log
  * then false is returned, meaning you ignore this log 
  *)
val receive_log : ?not_new_head:bool -> log_entry list -> bool

(**
  * upon new tail promotion make sure to commit entire log
  *)
val commit_log : unit -> unit

(* reset_sent will mark all log contents as unsent *)
val reset_sent : unit -> unit

(* reset clears all log state *)
val reset : unit -> unit
