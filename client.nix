{
  openvpnPort ? 1194,
  openvpnHost,
  vpnCAPath,
  vpnCertificatePath,
  vpnKeyPath,
  sshMasterPubKeyContent,
  sshPrivateKeyPath,
  sshPublicKeyPath,
  nixstorePrivateKeyPath,
  secrets,
  ...
}:

{ pkgs, config, ... }:

{
  networking.firewall = {
    allowedUDPPorts = [ 22 openvpnPort ];
    trustedInterfaces = [ "tun0" ];
  };

  nix = {
    extraOptions = ''
      secret-key-files = ${nixstorePrivateKeyPath}
    '';
    trustedUsers = [ "buildfarm" ];
    sshServe = {
      enable = true;
      keys = [ sshMasterPubKeyContent ];
      protocol = "ssh-ng";
    };
  };

  services = {
    openvpn.servers.client = {
      config = ''
        client
        float
        dev tun
        proto udp
        remote ${openvpnHost} ${builtins.toString openvpnPort}
        remote-cert-tls server

        ca ${vpnCAPath}
        cert ${vpnCertificatePath}
        key ${vpnKeyPath}
      '';
    };
    openssh = {
      enable = true;
      hostKeys = [ { type = "rsa"; bits = 4096; path = "/etc/ssh/ssh_host_rsa_key"; } ];
    };
  };

  # We force this in, because the pre-existing preStart script generates
  # the keypair on the first start but we won't need that and it would be
  # concatenated with this script otherwise.
  systemd.services.sshd.preStart = pkgs.lib.mkForce ''
    exec >&2
    mkdir -m 0755 -p /etc/ssh
    cp ${sshPrivateKeyPath} /etc/ssh/ssh_host_rsa_key
    chmod 400 /etc/ssh/ssh_host_rsa_key
    cp ${sshPublicKeyPath} /etc/ssh/ssh_host_rsa_key.pub
  '';

  users.extraUsers.buildfarm = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [ sshMasterPubKeyContent ];
  };
}
