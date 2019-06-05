{
  openvpnPort ? 1194,
  prefix,
  remoteHost,
  remoteName
}:

{ pkgs, config, ... }:

{
  networking.firewall.allowedUDPPorts = [ 22 openvpnPort ];
  networking.firewall.trustedInterfaces = [ "tun0" ];

  nix.trustedUsers = [ "buildfarm" ];

  services.openvpn.servers.client = {
    config = ''
      client
      float
      dev tun
      proto udp
      remote ${remoteHost} ${builtins.toString openvpnPort}
      remote-cert-tls server

      # Fix this: The keys should not be in the store, of course.
      ca ${./pki/ca.crt}
      cert ${./pki/issued + "/${prefix}.crt"}
      key ${./pki/private + "/${prefix}.key"}
    '';
  };
  services.openssh.enable = true;

  users.extraUsers.buildfarm = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      (builtins.readFile (./. + "/ssh_keys/buildfarm.pub"))
    ];
  };
}
