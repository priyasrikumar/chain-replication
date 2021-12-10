open Async

open Test_config_parser

type ret = {
  server_addrs : (string * int) list;
  client_addrs : (string * int) list;
  backup_addrs : (string * int) list;
  backup_args : string list list;
  failures : int list;
  duration : int;
}

let ret_transform ~parsed:{ server_addrs = sad; client_addrs = cad; backup_addrs = bad; server_args = _sar; client_args = _car; backup_args = bar; failures = f; duration = d} =
  {
    server_addrs = sad;
    client_addrs = cad;
    backup_addrs = bad;
    backup_args = bar;
    failures = f;
    duration = d;
  }

let kickoff ~server_prog:sp ~client_prog:cp
    ~parsed:{ server_addrs = _sad; client_addrs = _cad; backup_addrs = _bad; server_args = sar; client_args = car; backup_args = _bar; failures = _f; duration = _d} =
  Deferred.List.map sar ~f:(fun server_addr -> Process.create_exn ~prog:sp ~args:server_addr ()) >>=
  (fun sar' ->
    Deferred.List.map car ~f:(fun client_addr -> Process.create_exn ~prog:cp ~args:client_addr ()) >>|
    (fun car' -> (sar',car')))
