# Chain Replication Sans Coordinator

This is the public repository for Priya Srikumar and Goktug Saatcioglu's implementation of the Chain Replication Sans Coordinator project for the CS6410 course. This README describes how to build the program and how to execute it. There is also information on how to test the project in Mininet.

### Overview
  
The program has been written in OCaml and uses the [Async](https://opensource.janestreet.com/async/) library to perform concurrent operations. This means that the whole implementation is lock free and relies on Async's cooperative threading scheduler and promises to perform atomic updates to data that may be accessed by multiple threads. The project structure is split into three folders as follows:

* [`chainnode_src`](src/chainnode_src) contains all the files for the implementation of a node in a single chain;
* [`chainclient_src`](src/chainclient_src) contains all the files for the implementation of a client that interacts with chains;
* [`tester`](src/tester) contains all the files of the implementation of a tester that coordinates chain creation and clients beginning their testing process.

### Build Instructions

This program was written and tested with OCaml `4.11.0` and while the OCaml language claims backwards compatibility, it is best to run the program under this version of OCaml.

Instructions on installing OCaml on various systems is given [here](https://ocaml.org/docs/install.html). You should also install the OCaml package manager OPAM with your OCaml install.

The easiest way to satisfy all OCaml-related installation requirements is to install the OCaml package manager OPAM and then execute the following commands
  
```bash
opam switch 4.11.0
opam install -y ocamlbuild
eval $(opam config env) 
```

You will also need to install some libraries to get everything working. You can do this as follows.

```bash
opam install dune core async yojson
```

To compile the program run

```Makefile
dune build --root .
```

which will produce three files:

1. `chainnode.exe` under [`_build/default/chainnode_src/chain_bin/chainnode.exe`](_build/default/chainnode_src/chain_bin/chainnode.exe) (for creating a chain node);
2. `chainclient.exe` under [`_build/default/chainclient_src/client_bin/chainclient.exe`](_build/default/chainclient_src/client_bin/chainclient.exe) (for creating client nodes);
3. `tester.exe` under [`_build/default/tester/tester_bin/tester.exe`](_build/default/tester/tester_bin/tester.exe) (for testing the system).

### Running the Program

After building the program you may interact with any of the exectubales that have been produced.

For `chainnode.exe` you have the following command line arguments:

* `-ip [ip/string]` - required field, specify the ipv4 address this node should use;
* `port [port/int]` - required field, specify the port number this node should use;
* `-current-config [ipv4:port/string]` - optional field, specify a node in the current configuration this node is trying to join, can be used multiple times to get a chain;
* `-is-init` - optional flag, specify whether this node is the first node of the chain.
* `is-test` - optional flag, specify whether you wish to test the chain node or interact with it in interactive mode, in test mode operations initiate after a Tcp message is sent to the chain node;
* `-help`, `--help` - prints help messages.

For `chainclient.exe` you have the following command line arguments:

* `-ip [ip/string]` - required field, specify the ipv4 address this node should use;
* `port [port/int]` - required field, specify the port number this node should use;
* `-chain-length [/int]` - required field, length of the chain this client is interacting with;
* `-current-config [ipv4:port/string]` - optional field, specify a node in the current configuration this client is trying to interact with, can be used multiple times to get a chain;
* `is-test` - optional flag, specify whether you wish to test the chain or interact with it in interactive mode;
* `duration [/int]` - required field, how long the client should test the chain for;
* `ratio [0.<=x<=1./float]` - required field, the ratio of updates to queries the client produces during testing;
* `lbound [/int]` - required field, the first name of the objects the client queries and updates;
* `rbound [/int]` - required field, the last name of the objects the client queries and updates
* `wait` - optional flag, specify whether you want the client to wait before kicking off the testing (the command to start comes via TCP);
* `seed [/int]` - optional field, initialize random seed for the client;
* `-help`, `--help` - prints help messages.

For `tester.exe` you have the following command line arguments:

* `-server [ipv4:port/string]` - required field, specify a node in the chain this tester is trying to interact with, can be used multiple times to get a chain;
* `-client [ipv4:port/string]` - required field, specify a client of the chain this tester is trying to interact with, can be used multiple times to get multiple clients;
* `-backup [ipv4:port/string]` - required field, specify a node in the chain that can be used as a backup in the present of failures in chain this tester is trying to interact with, can be used multiple times to get a multiple backups;
* `-sp [.exe/string]` - optional field, path to where the chain program is located;
* `-cp [.exe/string]` - optional field, path to where the client program is located;
* `-config [text file with no extension/string]` - path to where the test config is located;
* `-duraction [/int]` - optional field, how long the testing should run for;
* `-failure [secondst/int]` - optional field, specify the amount of time should pass before a failure in the chain is simulated;
* `-mininet` - optional flag, use this flag if you are testing the program inside of mininet;
* `-help`, `--help` - prints help messages.

### Testing

Our testing is based on config files that take on the following format.

```text
servers=num1
clients=num2
backups=num3
duration=dur
ratio=rat
lbound=lbound_num
rbound=rbound_num
failures=fail1,fail2,fail3,...,failn
```

Here `num1` is the number of servers initially in the chain and `num2` is the number of clients interacting with the chain. `num3` is the number of backups available for the chain and can be `0`. The duration `dur` is an integer representing how long the experiments should run for and the ratio is given by `rat` which is a floating-point number between 0. and 1. The entire left bound and right bound of the objects being used by the system are specified by `lbound_num` and `rbound_num`. If you wish to simulate failures you can specify the time points they happen in by using comma separated integers `faili`.

We did most of our testing using [Mininet](http://mininet.org) and there are several Python scripts that run different experiments. We describe them below.

* `bench.py` - This test measures the throughput for different chain lengths with different ratios of query to update requests. Specify the path to the configuration files on line 13.
* `durbench.py` - This test measures the throughput for different chain lengths with different experiment lengths. Specify the path to the configuration files on line 13. 
* `testbench.py` - This test measures query and update throughput and runs a specified number of backup hosts with failures. Specify the path to the configuration files on line 14. 

