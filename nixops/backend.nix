let
  userOnlyKey = user: file: {
    text = builtins.readFile file;
    user = user;
    permissions = "0400";
  };
  rootOnlyKey = userOnlyKey "root";
  buildfarmOnlyKey = userOnlyKey "buildfarm";

  clientConfig = prefix: { config, pkgs, ... }: {
    deployment.targetEnv = "libvirtd";
    deployment.keys = {
      vpn-key = rootOnlyKey (../keys_certificates/pki/private + "/${prefix}.key");
      ssh-private = rootOnlyKey (../keys_certificates/ssh_keys + "/${prefix}");
      nixstore-private = buildfarmOnlyKey (../keys_certificates/nixstore_keys + "/${prefix}-priv.pem");
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

  client1 = clientConfig "openvpn_client1";
  client2 = clientConfig "openvpn_client2";
}
