open Async
open Core

let run ~sp ~cp ~config ~mininet ~servers ~clients ~backups ~duration ~failures =
  if mininet then
    let parsed = Test_config_parser.parse_mininet ~servers ~clients ~backups ~duration ~failures in
    Do_tests.go_with_mininet ~data:parsed >>|
    Time.Span.create ~sec:5 >>=
    after
  else
    let parsed = Test_config_parser.parse_proc_launch ~file:config in
    let data = Process_starter.ret_transform ~parsed:parsed in
    Process_starter.kickoff ~server_prog:sp ~client_prog:cp ~parsed:parsed >>=
    (fun _ -> Do_tests.go_with_procs ~server_prog:sp ~data:data) >>|
    Time.Span.create ~sec:5 >>=
    after
  (*Deferred.both
    (Process_starter.kickoff ~server_prog:sp ~client_prog:cp ~parsed:parsed)
    (Do_tests.go ~server_prog:sp ~data:data) >>=
  (fun (_,_) -> return ())*)

let () =
  Async.Command.async ~summary:"Start a chain node."
    Command.Let_syntax.(
      let%map_open sp =
        flag "-sp" (optional_with_default ("") string)
          ~doc:" Path to where the server program is located."
      and cp =
        flag "-cp" (optional_with_default ("") string)
          ~doc:" Path to where the client program is located."
      and config =
        flag "-config" (optional_with_default ("") string)
          ~doc:" Path to where the config program is located."
      and mininet =
        flag "-mininet" (no_arg)
          ~doc:" Use this flag if you are launching this program with mininet."
      and servers =
        flag "-server" (listed string) 
          ~doc:" Pass the initial chain configuration (ipv4:port format)."
      and clients =
        flag "-client" (listed string) 
          ~doc:" Pass the initial client addresses (ipv4:port format)."
      and backups =
        flag "-backup" (listed string) 
          ~doc:" Pass the backup addresses (ipv4:port format)."
      and duration =
        flag "-duration" (optional_with_default (0) int)
          ~doc:" Duration of the tests when using mininet."
      and failures =
        flag "-failure" (listed int)
          ~doc:" Time points where a failure should happen."
      in
      fun () -> run ~sp ~cp ~config ~mininet ~servers ~clients ~backups ~duration ~failures)
  |> Command.run
