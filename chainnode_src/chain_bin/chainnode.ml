open Async
open Core

let to_ports port = (port+1, port+2, port+3)

let cleanup servers =
  Chain_client.stop ();
  let rec cleaner ls =
    match ls with 
    | [] -> return () 
    | hd :: tl ->
      Tcp.Server.close hd >>= (fun () -> cleaner tl)
  in
  cleaner servers

let run ~ip ~port ~is_init ~is_test ~is_opt ~beliefs  =
  if Parser.validate_ipv4 ip && Parser.validate_port port then
    let (port1,port2,port3) = to_ports port in
    if is_init then begin Chain_config.add_proc ~ipv4:ip ~port:port1; Chain_config.join_chain (); Chain_log.add_proc ~ipv4:ip ~port:port1 end;
    Chain_test.test ~wait:is_test ~ipv4:ip ~port:port >>=
    (fun ok ->
      if ok then begin
        Chain_client.start ~is_opt:is_opt ();
        Deferred.all [Chain_server.mk ~ipv4:ip ~port:port1; Add_proc_server.mk ~ipv4:ip ~port:port2; Client_server.mk ~ipv4:ip ~port:port3] >>=
        (fun servers -> 
          if is_init then return (servers,true)
          else
            Add_proc_client.attempt_join ~ipv4:ip ~port:port1 ~potential_heads:(Parser.parse_beliefs beliefs) >>|
            (fun cond -> (servers,cond))) >>=
        (fun (servers,ok) ->
          if ok then Kill.iloop ~ipv4:ip ~port:port ~is_init:is_init >>= (fun () -> cleanup servers)
          else cleanup servers)
      end else return ())
  else Async.Print.printf "Bad input: (-ip,-port) pair." |> return

let () =
  Async.Command.async ~summary:"Start a chain node."
    Command.Let_syntax.(
      let%map_open ip =
        flag "-ip" (required string)
          ~doc:" Ip address of node."
      and port =
        flag "-port" (required int) (*(optional_with_default (10572) int)*)
          ~doc:" Port for node to listen on."
      and is_init =
        flag "-is-init" no_arg
          ~doc:" Whether this is the first node in the chain or not."
      and is_test =
        flag "-is-test" no_arg
          ~doc:" Whether this node is created in test mode, operations initiate after Tcp message is sent."
      and is_opt =
        flag "-is-opt" no_arg
          ~doc:" Whether this node uses log optimization."
      and beliefs =
        flag "-current-config" (listed string) 
          ~doc:" Pass the current config so that this node may join it (ipv4:port format)."
      in
      fun () -> run ~ip ~port ~is_init ~is_test ~is_opt ~beliefs)
  |> Command.run; exit 0
