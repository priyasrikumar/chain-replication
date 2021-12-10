type t = Async.Tcp.Server.inet

val mk : ipv4:string -> port:int -> t Async.Deferred.t
val rm : t -> unit Async_unix__.Import.Deferred.t
