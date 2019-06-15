pkgs:
ipPrefix:

let
  clientNames = pkgs.lib.filter (line: line != "")
    (pkgs.lib.splitString "\n" (builtins.readFile ./clientlist.txt));
  numerated = pkgs.lib.zipLists clientNames (builtins.genList (x: x) (builtins.length clientNames));
in pkgs.lib.flip builtins.map numerated ({fst, snd}: rec {
  name = fst;
  ip = ipPrefix + builtins.toString (snd + 2);

  sshPublicKeyPath = ./keys_certificates/ssh_keys + "/${name}.pub";
  sshPublicKey = builtins.readFile sshPublicKeyPath;
  nixstorePubkey = builtins.readFile (./keys_certificates/nixstore_keys + "/${name}-pub.pem");

  vpnCAPath = ./keys_certificates/pki/ca.crt;
  vpnCertificatePath = ./keys_certificates/pki/issued + "/${name}.crt";

  # We do not store the paths of private keys
  # - For nixops deployments, we will store these in the secret store.
  # - For nixos integration tests, there is no such secure store.
  secrets = {
    vpnKey = builtins.readFile (./keys_certificates/pki/private + "/${name}.key");
    sshPrivateKey = builtins.readFile (./keys_certificates/ssh_keys + "/${name}");
    nixstorePrivateKey = builtins.readFile (./keys_certificates/nixstore_keys + "/${name}-priv.pem");
  };
})
