let
  pkgs = import <nixpkgs> {};
  buildSlaves = import ../clientattributes.nix pkgs "10.8.0.";
  clientArguments = client: client // {
    openvpnPort = 1194;
    openvpnHost = "server";
    sshMasterPubKeyContent = builtins.readFile ../keys_certificates/ssh_keys/openvpn_server.pub;

    vpnKeyPath = "/run/keys/vpn-key";
    sshPrivateKeyPath = "/run/keys/ssh-private";
    nixstorePrivateKeyPath = "/run/keys/nixstore-private";
  };
  buildSlaveConfigs = builtins.map clientArguments buildSlaves;
in {
  network.description = "Nix hydra server and build slaves";

  server = import ../server.nix {
    vpnCAPath = ../keys_certificates/pki/ca.crt;
    vpnCertificatePath = ../keys_certificates/pki/issued/openvpn_server.crt;
    vpnKeyfilePath = "/run/keys/vpn-key";
    vpnDiffieHellmanFilePath = "/run/keys/dh-params";
    sshPrivateKeyPath = "/run/keys/sshkey-buildfarm";
    inherit buildSlaves;
  };
} // (
  builtins.listToAttrs (
    pkgs.lib.flip builtins.map (builtins.map clientArguments buildSlaves) (
      node: pkgs.lib.nameValuePair node.name (import ../client.nix node)
    )
  )
)
