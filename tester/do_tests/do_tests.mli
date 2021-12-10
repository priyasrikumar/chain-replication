val go_with_procs : server_prog:string -> data:Process_starter.ret -> unit Async.Deferred.t

val go_with_mininet : data:Test_config_parser.ret_mininet -> unit Async.Deferred.t
