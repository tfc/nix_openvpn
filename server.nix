{
  openvpnPort ? 1194,
  vpnCertificatePath,
  vpnCAPath,
  vpnKeyfilePath,
  vpnDiffieHellmanFilePath,
  sshPrivateKeyPath,
  buildSlaves
}:

{ pkgs, config, ... }:

let
  ippFile = pkgs.writeText "ipp.txt" (pkgs.lib.concatMapStringsSep "\n"
    ({name, ip, ...}: "${name},${ip}") buildSlaves);
in {
  networking = {
    firewall.allowedUDPPorts = [ openvpnPort ];
    firewall.allowedTCPPorts = [
      9090 # prometheus
    ];
    hosts = builtins.listToAttrs (
      builtins.map (node: pkgs.lib.nameValuePair node.ip [ node.name ]) buildSlaves
    );
  };

  nix = {
    buildMachines = let
      f = { ip, ...}: {
        hostName = ip;
        sshUser = "buildfarm";
        sshKey = sshPrivateKeyPath;
        system = "x86_64-linux";
        maxJobs = 1;
      };
      in builtins.map f buildSlaves;

    distributedBuilds = true;

    extraOptions = ''
      connect-timeout = 5
    '';

    binaryCachePublicKeys = builtins.map
      ({ nixstorePubkey, ... }: nixstorePubkey) buildSlaves;
    binaryCaches = [ "https://cache.nixos.org/" ]
      ++ (builtins.map ({ ip, ... }: "ssh-ng://${ip}") buildSlaves);
    trustedBinaryCaches = builtins.map
      ({ ip, ... }: "ssh-ng://${ip}") buildSlaves;
  };

  programs.ssh.extraConfig = ''
    Host 10.8.0.*
      User buildfarm
      IdentityFile ${sshPrivateKeyPath}
      ConnectTimeout 5
  '';

  programs.ssh.knownHosts = let
    f = { ip, name, sshPublicKey, ...}: pkgs.lib.nameValuePair
      name
      { hostNames = [ ip name ]; publicKey = sshPublicKey; };
  in builtins.listToAttrs (builtins.map f buildSlaves);

  services = {
    hydra = {
      enable = true;
      hydraURL = "http://localhost:3000";
      notificationSender = "jacek@galowicz.de";
      useSubstitutes = true;
    };
    openssh.enable = true;
    openvpn.servers.server = {
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
    prometheus = {
      enable = true;
      scrapeConfigs = [{
        job_name = "buildfarm";
        static_configs = let
          f = { ip, name, ...}: {
            targets = [ "${ip}:9100" ];
            labels = { instance = name; };
          };
        in builtins.map f buildSlaves;
      }];
    };
  };

  systemd.services.openvpn-server.preStart = ''
    if [ ! -f /root/ipp.txt ]; then
      cp ${ippFile} /root/ipp.txt
    fi
  '';
}
