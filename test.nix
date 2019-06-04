{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {}
}:

let
  f = { pkgs, ...}: {
    name = "openvpn_test";
    nodes = {
      server = import ./server.nix {};
      client1 = import ./client.nix {
        prefix = "openvpn_client1";
        remoteHost = "server";
        remoteName = "openvpn_server";
      };
    };

    testScript = { nodes, ... }: ''
      $server->start();
      $server->waitForUnit("openvpn-server.service");
      print($server->succeed("ifconfig tun0"));

      $client1->start();
      $client1->waitForUnit("openvpn-client.service");
      $client1->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("ping -c1 10.8.0.2");
      $client1->succeed("ping -c1 10.8.0.1");
    '';
  };
in import "${pkgs.path}/nixos/tests/make-test.nix" f {}
