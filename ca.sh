#!/usr/bin/env nix-shell
#!nix-shell -i bash -p easyrsa

set -eu

easyrsa init-pki
easyrsa build-ca nopass
easyrsa gen-dh
easyrsa build-server-full openvpn_server nopass
easyrsa build-client-full openvpn_client1 nopass
easyrsa build-client-full openvpn_client2 nopass

mkdir -p ssh_keys
ssh-keygen -t rsa -f ssh_keys/buildfarm -q -N ""
