let
  userOnlyKey = user: file: {
    text = builtins.readFile file;
    user = user;
    permissions = "0400";
  };
  rootOnlyKey = userOnlyKey "root";
  buildfarmOnlyKey = userOnlyKey "buildfarm";

  pkgs = import <nixpkgs> {};
  buildSlaves = import ../clientattributes.nix pkgs "10.8.0.";

  clientConfig = { name, ... }: { config, pkgs, ... }: {
    deployment.targetEnv = "libvirtd";
    deployment.keys = {
      vpn-key = rootOnlyKey (../keys_certificates/pki/private + "/${name}.key");
      ssh-private = rootOnlyKey (../keys_certificates/ssh_keys + "/${name}");
      nixstore-private = buildfarmOnlyKey (../keys_certificates/nixstore_keys + "/${name}-priv.pem");
    };
  };
in {
  server = { config, pkgs, ... }: {
    deployment.targetEnv = "libvirtd";
    deployment.keys = {
      vpn-key = rootOnlyKey ../keys_certificates/pki/private/openvpn_server.key;
      dh-params = rootOnlyKey ../keys_certificates/pki/dh.pem;
      sshkey-buildfarm = rootOnlyKey ../keys_certificates/ssh_keys/openvpn_server;
    };
  };
} // (
  builtins.listToAttrs (
    builtins.map
      (node: pkgs.lib.nameValuePair node.name (clientConfig node))
      buildSlaves
  )
)
