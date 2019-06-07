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
      vpn-key = rootOnlyKey (../pki/private + "/${prefix}.key");
    };
  };
in {
  server = { config, pkgs, ... }: {
    deployment.targetEnv = "libvirtd";
    deployment.keys = {
      vpn-key = rootOnlyKey ../pki/private/openvpn_server.key;
      dh-params = rootOnlyKey ../pki/dh.pem;
      sshkey-buildfarm = rootOnlyKey ../ssh_keys/buildfarm;
    };
  };

  client1 = clientConfig "openvpn_client1";
  client2 = clientConfig "openvpn_client2";
}
