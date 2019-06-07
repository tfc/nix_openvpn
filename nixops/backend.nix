let
  rootOnlyKey = file: {
    text = builtins.readFile file;
    user = "root";
    group = "root";
    permissions = "0400";
  };
  clientConfig = prefix: { config, pkgs, ... }: {
    deployment.targetEnv = "libvirtd";
    deployment.keys = {
      vpn-key = rootOnlyKey (../keys_certificates/pki/private + "/${prefix}.key");
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
