{
  openvpnPort ? 1194,
  vpnCertificatePath,
  vpnCAPath,
  vpnKeyfilePath,
  vpnDiffieHellmanFilePath,
  sshPrivateKeyPath,
  buildSlaveNameIpPairs
}:

{ pkgs, config, ... }:

let
  ippFile = pkgs.writeText "ipp.txt" (pkgs.lib.concatMapStringsSep "\n"
    ({name, ip}: "${name},${ip}") buildSlaveNameIpPairs);
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
      #chmod 600 /root/ip.txt
    fi
  '';

  nix.buildMachines = let
    f = { ip, ...}: {
      hostName = ip;
      sshUser = "buildfarm";
      sshKey = sshPrivateKeyPath;
      system = "x86_64-linux";
      maxJobs = 1;

    };
  in builtins.map f buildSlaveNameIpPairs;

  nix.distributedBuilds = true;

  programs.ssh.extraConfig = ''
    Host 10.8.0.*
      User buildfarm
      IdentityFile ${sshPrivateKeyPath}
      ConnectTimeout 5
  '';
}
