open Core

let run ~ipv4 ~port ~duration ~l_bound ~r_bound ~ratio ~is_test ~wait ~beliefs ~chain_length ~seed =
  Parser.parse_beliefs beliefs |> List.iter ~f:(fun (ipv4,port) -> Client_config.add_tail ~ipv4:ipv4 ~port:port);
  if is_test && Parser.validate_ipv4 ipv4 && Parser.validate_port port then
    Client_test.test ~seed ~chain_length ~wait ~duration ~l_bound ~r_bound ~ratio ~ipv4 ~port
  else Iloop.iloop ()

let () =
  Async.Command.async ~summary:"Start a chain node."
    Command.Let_syntax.(
      let%map_open ipv4 =
        flag "-ip" (optional_with_default ("0.0.0.0") string)
          ~doc:" Ip address of node."
      and port =
        flag "-port" (optional_with_default (0) int)
          ~doc:" Port for node to listen on."
      and duration =
        flag "-duration" (optional_with_default (0) int)
          ~doc:" Duration of the testing period."
      and l_bound =
        flag "-lbound" (optional_with_default (0) int)
          ~doc:" Left bound of objects owned by this client."
      and r_bound =
        flag "-rbound" (optional_with_default (0) int)
          ~doc:" Right bound of objects owned by this client."
      and ratio =
        flag "-ratio" (optional_with_default (0.) float)
          ~doc:" Ratio of updates to queries in testing."
      and wait =
        flag "-wait" no_arg
          ~doc:" Whether you want to want to wait before kicking off the testing (this command to start comes via TCP)."
      and is_test =
        flag "-is-test" no_arg
          ~doc:" Whether you want to run in interactive mode or test mode."
      and beliefs =
        flag "-current-config" (listed string) 
          ~doc:" Pass the current config so that this client may start making requests join it (ipv4:port format)."
      and chain_length =
        flag "-chain-length" (optional_with_default (1) int)
          ~doc:" Length of the chain this client is interacting with."
      and seed =
        flag "-seed" (optional_with_default (0) int)
          ~doc:" Integer for random seed for testing rng."
      in
      fun () -> run ~ipv4 ~port ~duration ~l_bound ~r_bound ~ratio ~wait ~is_test ~beliefs ~chain_length ~seed)
  |> Command.run; exit 0
