{
  openvpnPort ? 1194,
  vpnCertificatePath,
  vpnCAPath,
  vpnKeyfilePath,
  vpnDiffieHellmanFilePath,
  sshPrivateKeyPath,
  buildSlaveInfo
}:

{ pkgs, config, ... }:

let
  ippFile = pkgs.writeText "ipp.txt" (pkgs.lib.concatMapStringsSep "\n"
    ({name, ip, ...}: "${name},${ip}") buildSlaveInfo);
  knownHostsFile = pkgs.writeText "known_hosts" (pkgs.lib.concatMapStringsSep "\n"
    ({pubkey, ip, ...}: "${ip} ${pubkey}") buildSlaveInfo);
in {
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
      ifconfig-pool-persist /root/ipp.txt
      push "route 10.8.0.0 255.255.255.0"

      ca ${vpnCAPath}
      cert ${vpnCertificatePath}
      key ${vpnKeyfilePath}
      dh ${vpnDiffieHellmanFilePath}

      keepalive 10 120
    '';
  };

  systemd.services.openvpn-server.preStart = ''
    if [ ! -f /root/ipp.txt ]; then
      cp ${ippFile} /root/ipp.txt
    fi

    if [ ! -f /root/.ssh/known_hosts ]; then
      mkdir -p /root/.ssh
      cp ${knownHostsFile} /root/.ssh/known_hosts
    fi
  '';

  nix = {
    buildMachines = let
      f = { ip, ...}: {
        hostName = ip;
        sshUser = "buildfarm";
        sshKey = sshPrivateKeyPath;
        system = "x86_64-linux";
        maxJobs = 1;
      };
      in builtins.map f buildSlaveInfo;

    distributedBuilds = true;

    extraOptions = ''
      connect-timeout = 5
    '';

    binaryCachePublicKeys = builtins.map ({ nixstorePubkey, ... }: nixstorePubkey) buildSlaveInfo;
    binaryCaches = [ "https://cache.nixos.org/" ] ++ (builtins.map ({ ip, ... }: "ssh-ng://${ip}") buildSlaveInfo);
    trustedBinaryCaches = builtins.map ({ ip, ... }: "ssh-ng://${ip}") buildSlaveInfo;
  };

  programs.ssh.extraConfig = ''
    Host 10.8.0.*
      User buildfarm
      IdentityFile ${sshPrivateKeyPath}
      ConnectTimeout 5
  '';
}
