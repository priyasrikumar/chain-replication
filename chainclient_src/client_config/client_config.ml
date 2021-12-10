open Core

type node = {
  ipv4 : string;
  port : int;
}

let config : node Deque.t = Deque.create ()

let add_head ~ipv4:ipv4 ~port:port =
  let new_head = {
    ipv4 = ipv4;
    port = port;
  }
  in
  Deque.enqueue_front config new_head

let add_tail ~ipv4:ipv4 ~port:port =
  let new_tail = {
    ipv4 = ipv4;
    port = port;
  }
  in
  Deque.enqueue_front config new_tail

let kill_head () = Deque.drop_front config
let kill_tail () = Deque.drop_back config

let get_head () = Option.map (Deque.peek_front config) ~f:(fun node -> (node.ipv4,node.port))
let get_tail () = Option.map (Deque.peek_back config) ~f:(fun node -> (node.ipv4,node.port))
