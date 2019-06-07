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
    vpnCAPath = ./keys_certificates/pki/ca.crt;
    vpnCertificatePath = ./keys_certificates/pki/issued + "/${prefix}.crt";
    vpnKeyfilePath = ./keys_certificates/pki/private + "/${prefix}.key";
    sshMasterPubKeyContent = builtins.readFile ./keys_certificates/ssh_keys/openvpn_server.pub;
    sshPrivateKeyPath = ./keys_certificates/ssh_keys + "/${prefix}";
    sshPublicKeyPath = ./keys_certificates/ssh_keys + "/${prefix}.pub";
  };
  f = { pkgs, ...}: {
    name = "openvpn_test";
    nodes = {
      server = import ./server.nix {
        vpnCAPath = ./keys_certificates/pki/ca.crt;
        vpnCertificatePath = ./keys_certificates/pki/issued/openvpn_server.crt;
        vpnKeyfilePath = ./keys_certificates/pki/private/openvpn_server.key;
        vpnDiffieHellmanFilePath = ./keys_certificates/pki/dh.pem;
        sshPrivateKeyPath = "/root/openvpn_server";
        buildSlaveInfo = [
          { ip = "10.8.0.2"; name = "openvpn_client1"; pubkey = builtins.readFile ./keys_certificates/ssh_keys/openvpn_client1.pub; }
          { ip = "10.8.0.3"; name = "openvpn_client2"; pubkey = builtins.readFile ./keys_certificates/ssh_keys/openvpn_client2.pub; }
        ];
      };
      client1 = import ./client.nix (clientArguments "openvpn_client1");
      client2 = import ./client.nix (clientArguments "openvpn_client2");
    };

    testScript = { nodes, ... }: ''
      $server->start();
      $server->waitForUnit("openvpn-server.service");
      $server->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("cp ${./. + "/keys_certificates/ssh_keys/openvpn_server"} /root/openvpn_server && chmod 0400 /root/openvpn_server");

      $client1->start();
      $client1->waitForUnit("openvpn-client.service");

      $client1->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("ping -c1 10.8.0.2");
      $client1->succeed("ping -c1 10.8.0.1");

      $server->succeed("nix ping-store --store ssh://10.8.0.2");

      $client2->start();
      $client2->waitForUnit("openvpn-client.service");
      $client2->succeed("sleep 1 && ifconfig tun0");
      $server->succeed("ping -c1 10.8.0.3");
      $client2->succeed("ping -c1 10.8.0.1");

      print($server->succeed("nix-build -j0 ${trivialHostnameDerivation nodes.server.config "foo"}"));
      $client1->block;
      print($server->succeed("nix-build -j0 ${trivialHostnameDerivation nodes.server.config "bar"}"));
    '';
  };
in import "${pkgs.path}/nixos/tests/make-test.nix" f {}
