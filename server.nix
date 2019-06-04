{
  openvpnPort ? 1194
}:

{ pkgs, config, ... }:

{
  networking.firewall.allowedUDPPorts = [ openvpnPort ];
  services.openvpn.servers.server = {
    config = ''
      port ${builtins.toString openvpnPort}
      proto udp
      mode server
      tls-server
      dev tun

      topology subnet
      ifconfig 10.8.0.1 255.255.255.0
      ifconfig-pool 10.8.0.2 10.8.0.200
      ifconfig-pool-persist ipp.txt
      push "route 10.8.0.0 255.255.255.0"

      # Fix this: The keys should not be in the store, of course.
      ca ${./pki/ca.crt}
      cert ${./pki/issued/openvpn_server.crt}
      key ${./pki/private/openvpn_server.key}
      dh ${./pki/dh.pem}

      keepalive 10 120
    '';
  };
}
