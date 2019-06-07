{
  openvpnPort ? 1194,
  remoteHost,
  remoteName,
  vpnCAPath,
  vpnCertificatePath,
  vpnKeyfilePath,
  sshMasterPubKeyContent,
  sshPrivateKeyPath,
  sshPublicKeyPath
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

  # We force this in, because the pre-existing preStart script generates
  # the keypair on the first start but we won't need that and it would be
  # concatenated with this script otherwise.
  systemd.services.sshd.preStart = pkgs.lib.mkForce ''
    cp ${sshPrivateKeyPath} /etc/ssh/ssh_host_rsa_key
    chmod 400 /etc/ssh/ssh_host_rsa_key
    cp ${sshPublicKeyPath} /etc/ssh/ssh_host_rsa_key.pub
  '';

  users.extraUsers.buildfarm = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [ sshMasterPubKeyContent ];
  };
}
