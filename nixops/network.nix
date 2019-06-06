let
  clientArguments = prefix: {
    remoteHost = "server";
    remoteName = "openvpn_server";
    vpnCAPath = ./pki/ca.crt;
    vpnCertificatePath = ./pki/issued + "/${prefix}.crt";
    vpnKeyfilePath = "/run/keys/vpn-key";
    sshMasterPubKeyContent = builtins.readFile ./ssh_keys/buildfarm.pub;
  };
in {
  network.description = "Nix hydra server and build slaves";

  server = import ./server.nix {
    vpnCAPath = ./pki/ca.crt;
    vpnCertificatePath = ./pki/issued/openvpn_server.crt;
    vpnKeyfilePath = "/run/keys/vpn-key";
    vpnDiffieHellmanFilePath = "/run/keys/dh-params";
    sshPrivateKeyPath = "/run/keys/sshkey-buildfarm";
    buildSlaveHostnames = [ "10.8.0.2" "10.8.0.3" ];
  };
  client1 = import ./client.nix (clientArguments "openvpn_client1");
  client2 = import ./client.nix (clientArguments "openvpn_client2");
}
