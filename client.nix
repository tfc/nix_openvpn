{
  openvpnPort ? 1194,
  prefix,
  remoteHost,
  remoteName
}:

{ pkgs, config, ... }:

{
  networking.firewall.allowedUDPPorts = [ openvpnPort ];
  services.openvpn.servers.client = {
    config = ''
      client
      float
      dev tun
      proto udp
      remote ${remoteHost} ${builtins.toString openvpnPort}
      remote-cert-tls server

      ca ${./pki/ca.crt}
      cert ${./pki/issued + "/${prefix}.crt"}
      key ${./pki/private + "/${prefix}.key"}
    '';
  };
}
