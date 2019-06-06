{
  openvpnPort ? 1194,
  vpnCertificatePath,
  vpnCAPath,
  vpnKeyfilePath,
  vpnDiffieHellmanFilePath,
  sshPrivateKeyPath,
  buildSlaveHostnames
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

      ca ${vpnCAPath}
      cert ${vpnCertificatePath}
      key ${vpnKeyfilePath}
      dh ${vpnDiffieHellmanFilePath}

      keepalive 10 120
    '';
  };

  nix.buildMachines = let
    f = hostName: {
      inherit hostName;
      sshUser = "buildfarm";
      sshKey = sshPrivateKeyPath;
      system = "x86_64-linux";
      maxJobs = 1;

    };
  in builtins.map f buildSlaveHostnames;

  nix.distributedBuilds = true;

  programs.ssh.extraConfig = ''
    Host 10.8.0.*
      User buildfarm
      IdentityFile ${sshPrivateKeyPath}
  '';
}
