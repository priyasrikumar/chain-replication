type ret = {
  server_addrs : (string * int) list;
  client_addrs : (string * int) list;
  backup_addrs : (string * int) list;
  backup_args : string list list;
  failures : int list;
  duration : int;
}

val ret_transform : parsed:Test_config_parser.ret_proc_launch -> ret 
val kickoff : server_prog:string -> client_prog:string -> parsed:Test_config_parser.ret_proc_launch -> (Async.Process.t list * Async.Process.t list) Async.Deferred.t
