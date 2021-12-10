open Core

let db : (string, int) Hashtbl.t = Hashtbl.create (module String)

let add ~key:key ~num:num = Hashtbl.update db key ~f:(fun _ -> num)

let get ~key:key = Hashtbl.find db key 

let rem ~key:key = Hashtbl.remove db key
