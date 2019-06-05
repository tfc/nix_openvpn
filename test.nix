{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {}
}:

let
  trivialHostnameDerivation = config: foo:
    pkgs.writeText "expr.nix" ''
      let b = builtins.storePath ${config.system.build.extraUtils}; in
      derivation {
        name = "hostname-output";
        system = builtins.currentSystem;
        PATH = "''${b}/bin";
        builder = "''${b}/bin/sh";
        args = [ "-c" "echo ${foo}; cat /proc/sys/kernel/hostname > $out" ];
      }
    '';
  f = { pkgs, ...}: {
    name = "openvpn_test";
    nodes = {
      server = import ./server.nix {};
      client1 = import ./client.nix {
        prefix = "openvpn_client1";
        remoteHost = "server";
        remoteName = "openvpn_server";
      };
      client2 = import ./client.nix {
        prefix = "openvpn_client2";
        remoteHost = "server";
        remoteName = "openvpn_server";
      };
    };

    testScript = { nodes, ... }: ''
      $server->start();
      $server->waitForUnit("openvpn-server.service");
      $server->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("cp ${./. + "/ssh_keys/buildfarm"} /root/buildfarmkey && chmod 0400 /root/buildfarmkey");

      $client1->start();
      $client1->waitForUnit("openvpn-client.service");
      $client1->waitForUnit("sshd.service");

      $client1->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("ping -c1 10.8.0.2");
      $client1->succeed("ping -c1 10.8.0.1");

      $server->succeed("ssh -o StrictHostKeyChecking=no 10.8.0.2 nix-store --version");
      $server->succeed("nix ping-store --store ssh://10.8.0.2");

      $client2->start();
      $client2->waitForUnit("openvpn-client.service");
      $client2->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("ping -c1 10.8.0.3");
      $client2->succeed("ping -c1 10.8.0.1");

      $server->succeed("ssh -o StrictHostKeyChecking=no 10.8.0.3 nix-store --version");
      print($server->succeed("nix-build -j0 ${trivialHostnameDerivation nodes.server.config "foo"}"));
      $client1->block;
      print($server->succeed("nix-build -j0 ${trivialHostnameDerivation nodes.server.config "bar"}"));
    '';
  };
in import "${pkgs.path}/nixos/tests/make-test.nix" f {}
