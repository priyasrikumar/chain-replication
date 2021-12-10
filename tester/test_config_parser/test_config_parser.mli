type ret_proc_launch = {
  server_addrs : (string * int) list;
  client_addrs : (string * int) list;
  backup_addrs : (string * int) list;
  server_args : string list list;
  client_args : string list list;
  backup_args : string list list;
  failures : int list;
  duration : int;
}

type ret_mininet = {
  server_addrs : (string * int) list;
  client_addrs : (string * int) list;
  backup_addrs : (string * int) list;
  failures : int list;
  duration : int;
}

val parse_proc_launch : file:string -> ret_proc_launch

val parse_mininet : servers:string list -> clients:string list -> backups:string list ->
  failures:int list -> duration:int -> ret_mininet
