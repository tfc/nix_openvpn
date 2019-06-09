let
  clientArguments = prefix: {
    remoteHost = "server";
    remoteName = "openvpn_server";
    vpnCAPath = ../keys_certificates/pki/ca.crt;
    vpnCertificatePath = ../keys_certificates/pki/issued + "/${prefix}.crt";
    vpnKeyfilePath = "/run/keys/vpn-key";
    sshMasterPubKeyContent = builtins.readFile ../keys_certificates/ssh_keys/openvpn_server.pub;
    sshPrivateKeyPath = "/run/keys/ssh-private";
    sshPublicKeyPath = ../keys_certificates/ssh_keys + "/${prefix}.pub";
    nixstorePrivateKeyPath = "/run/keys/nixstore-private";
  };
in {
  network.description = "Nix hydra server and build slaves";

  server = import ../server.nix {
    vpnCAPath = ../keys_certificates/pki/ca.crt;
    vpnCertificatePath = ../keys_certificates/pki/issued/openvpn_server.crt;
    vpnKeyfilePath = "/run/keys/vpn-key";
    vpnDiffieHellmanFilePath = "/run/keys/dh-params";
    sshPrivateKeyPath = "/run/keys/sshkey-buildfarm";
    buildSlaveInfo = let
      f = ip: name: {
        inherit ip name;
        pubkey = builtins.readFile (../keys_certificates/ssh_keys + "/${name}.pub");
        nixstorePubkey = builtins.readFile (../keys_certificates/nixstore_keys + "/${name}-pub.pem");
      };
    in [
      (f "10.8.0.2" "openvpn_client1")
      (f "10.8.0.3" "openvpn_client2")
    ];
  };
  client1 = import ../client.nix (clientArguments "openvpn_client1");
  client2 = import ../client.nix (clientArguments "openvpn_client2");
}
