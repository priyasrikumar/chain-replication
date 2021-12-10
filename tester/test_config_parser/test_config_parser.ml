open Core

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

let parse_single line =
  match String.split line ~on:'=' with
  | _ :: hd2 :: [] -> hd2
  | _ -> "Impossible case for test parsing."

let parse_addrs line = 
  match String.split line ~on:'=' with
  | _ :: "" :: [] -> []
  | _ :: hd2 :: [] -> 
    List.map (String.split hd2 ~on:',') ~f:(fun addr ->
      match String.split addr ~on:':' with
      | ipv4 :: port :: [] -> (ipv4, Int.of_string port)
      | _ -> failwith "Impossible case for test parsing.")
  | _ -> failwith "Impossible case for test parsing."

let parse_failures line =
  match String.split line ~on:'=' with
  | _ :: "" :: [] -> []
  | _ :: hd2 :: [] -> List.map (String.split hd2 ~on:',') ~f:Int.of_string
  | _ -> failwith "Impossible case for test parsing."

let str_to_ip_port str =
  match String.split str ~on:':' with
  | ipv4 :: port :: [] -> (ipv4, Int.of_string port)
  | _ -> failwith "Something is wrong with supplied ip addresss"

let parse_mininet ~servers ~clients ~backups ~failures ~duration =
  let chain_addrs = List.map servers ~f:str_to_ip_port in
  let client_addrs = List.map clients ~f:str_to_ip_port in
  let backup_chain_addrs = List.map backups ~f:str_to_ip_port in
  if List.length failures <> 0 then assert (List.length failures <= List.length backup_chain_addrs);
  {
    server_addrs = chain_addrs;
    client_addrs = client_addrs;
    backup_addrs = backup_chain_addrs;
    failures = failures;
    duration = duration
  }

let parse_proc_launch ~file:f_name =
  Stdio.In_channel.with_file f_name
    ~f:(fun f ->
      let chain_addrs = Stdio.In_channel.input_line_exn f |> parse_addrs in
      let client_addrs = Stdio.In_channel.input_line_exn f |> parse_addrs in
      let backup_chain_addrs = Stdio.In_channel.input_line_exn f |> parse_addrs in
      let duration = Stdio.In_channel.input_line_exn f |> parse_single |> Int.of_string in
      let ratio = Stdio.In_channel.input_line_exn f |> parse_single  |> Float.of_string in
      let lbound = Stdio.In_channel.input_line_exn f |> parse_single  |> Int.of_string in
      let rbound = Stdio.In_channel.input_line_exn f |> parse_single  |> Int.of_string in
      let delta = if List.length client_addrs = 0 then 0 else (rbound - lbound) / (List.length client_addrs) in 
      let failures = Stdio.In_channel.input_line_exn f |> parse_failures in
      let chain_config_arg =
        List.concat_map chain_addrs
          ~f:(fun (ipv4,port) -> "-current-config" :: (Format.sprintf "%s:%d" ipv4 (port + 2)) :: [])
      in
      let client_config_arg =
        List.concat_map chain_addrs
          ~f:(fun (ipv4,port) -> "-current-config" :: (Format.sprintf "%s:%d" ipv4 (port + 3)) :: [])
      in
      let chain_args =
        List.mapi chain_addrs
          ~f:(fun i (ipv4,port) ->
            if i = 0 then 
              "-ip" :: ipv4 ::
              "-port" :: (Int.to_string port) ::
              "-is-init" :: "-is-test" ::
              chain_config_arg
            else
              "-ip" :: ipv4 ::
              "-port" :: (Int.to_string port) ::
              "-is-test" ::
              chain_config_arg)
      in
      let backup_args =
        List.map backup_chain_addrs
          ~f:(fun (ipv4,port) ->
            "-ip" :: ipv4 ::
            "-port" :: (Int.to_string port) ::
            "-is-test" ::
            chain_config_arg)
      in
      let client_args =
        List.mapi client_addrs
          ~f:(fun i (ipv4,port) ->
            "-ip" :: ipv4 ::
            "-port" :: (Int.to_string port) ::
            "-duration" :: (Int.to_string duration) ::
            "-lbound" :: (Int.to_string (lbound + (i * delta))) ::
            "-rbound" :: (Int.to_string (lbound + ((i + 1) * delta))) ::
            "-ratio" :: (Float.to_string ratio) ::
            "-wait" :: "-is-test" ::
            client_config_arg)
      in
      assert (List.length failures = List.length backup_chain_addrs);
      {
        server_addrs = chain_addrs;
        client_addrs = client_addrs;
        backup_addrs = backup_chain_addrs;
        server_args = chain_args;
        client_args = client_args;
        backup_args = backup_args;
        failures = failures;
        duration = duration;
      })
