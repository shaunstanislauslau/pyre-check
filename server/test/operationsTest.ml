(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open Core

open OUnit2
open Pyre
open Path.AppendOperator

let test_socket_path context =
  let root =
    bracket_tmpdir context
    |> Path.create_absolute
  in
  let configuration = Configuration.Analysis.create ~project_root:root ~local_root:root () in
  let socket_link = Service.Constants.Server.root configuration ^| "server.sock" in
  let preexisting = Path.create_relative ~root ~relative:"preexisting.sock" in
  File.write (File.create ~content:"1234" preexisting);
  Unix.symlink ~src:(Path.absolute preexisting) ~dst:(Path.absolute socket_link);
  assert_equal (Filename.realpath (Path.absolute socket_link)) (Path.absolute preexisting);

  (* Reading the socket path gives us the preexisting file. *)
  assert_equal
    ~cmp:Path.equal
    ~printer:Path.absolute
    (Server.Operations.socket_path ~create:false configuration)
    preexisting;
  assert_equal
    ~printer:ident
    (Unix.readlink (Path.absolute socket_link))
    (Path.absolute preexisting);

  (* Creating always overrides existing sockets. *)
  let actual_path =
    Format.sprintf "%s/pyre_%d.sock" Filename.temp_dir_name (Unix.getpid () |> Pid.to_int)
  in
  assert_equal
    ~printer:ident
    (Server.Operations.socket_path ~create:true configuration
     |> Path.absolute)
    actual_path;
  assert_equal ~printer:ident (Unix.readlink (Path.absolute socket_link)) actual_path


let () =
  "operations">:::[
    "socket_path">::test_socket_path;
  ]
  |> Test.run
