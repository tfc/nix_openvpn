{
  openvpnPort ? 1194,
  remoteHost,
  remoteName,
  vpnCAPath,
  vpnCertificatePath,
  vpnKeyfilePath,
  sshMasterPubKeyContent
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

      ca ${vpnCAPath}
      cert ${vpnCertificatePath}
      key ${vpnKeyfilePath}
    '';
  };
  services.openssh.enable = true;

  users.extraUsers.buildfarm = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [ sshMasterPubKeyContent ];
  };
}
