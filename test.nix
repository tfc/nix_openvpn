{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {}
}:

let
  trivialHostnameDerivation = config: foo:
    pkgs.writeText "expr.nix" ''
      let b = builtins.storePath ${config.system.build.extraUtils}; in
      derivation {
        name = "hostname-output-${foo}";
        system = builtins.currentSystem;
        PATH = "''${b}/bin";
        builder = "''${b}/bin/sh";
        args = [ "-c" "cat /proc/sys/kernel/hostname > $out" ];
      }
    '';
  clientArguments = prefix: {
    remoteHost = "server";
    remoteName = "openvpn_server";
    vpnCAPath = ./pki/ca.crt;
    vpnCertificatePath = ./pki/issued + "/${prefix}.crt";
    vpnKeyfilePath = ./pki/private + "/${prefix}.key";
    sshMasterPubKeyContent = builtins.readFile ./ssh_keys/buildfarm.pub;
  };
  f = { pkgs, ...}: {
    name = "openvpn_test";
    nodes = {
      server = import ./server.nix {
        vpnCAPath = ./pki/ca.crt;
        vpnCertificatePath = ./pki/issued/openvpn_server.crt;
        vpnKeyfilePath = ./pki/private/openvpn_server.key;
        vpnDiffieHellmanFilePath = ./pki/dh.pem;
        sshPrivateKeyPath = "/root/buildfarmkey";
        buildSlaveHostnames = [ "10.8.0.2" "10.8.0.3" ];
      };
      client1 = import ./client.nix (clientArguments "openvpn_client1");
      client2 = import ./client.nix (clientArguments "openvpn_client2");
    };

    testScript = { nodes, ... }: ''
      $server->start();
      $server->waitForUnit("openvpn-server.service");
      $server->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("cp ${./. + "/ssh_keys/buildfarm"} /root/buildfarmkey && chmod 0400 /root/buildfarmkey");

      $client1->start();
      $client1->waitForUnit("openvpn-client.service");

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
