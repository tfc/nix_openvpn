#!/usr/bin/env nix-shell
#!nix-shell -i bash -p easyrsa

set -eu

rm -rf keys_certificates
mkdir keys_certificates

pushd keys_certificates

easyrsa init-pki

easyrsa --batch --req-cn="Jonge" build-ca nopass

easyrsa gen-dh
easyrsa build-server-full openvpn_server nopass

for client in $(cat ../clientlist.txt); do
  easyrsa build-client-full "$client" nopass
done

mkdir -p ssh_keys
ssh-keygen -t rsa -f ssh_keys/openvpn_server -q -N ""

for client in $(cat ../clientlist.txt); do
  ssh-keygen -t rsa -f "ssh_keys/$client" -q -N ""
done
