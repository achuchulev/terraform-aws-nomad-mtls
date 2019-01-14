#!/usr/bin/env bash

sudo mkdir /etc/nginx/ssl
sudo cd /etc/nginx/ssl

# Generate the CA's private key and certificate
cfssl print-defaults csr | cfssl gencert -initca - | cfssljson -bare nginx-ca

# Generate a certificate for the nginx server
echo '{}' | cfssl gencert -ca=nginx-ca.pem -ca-key=nginx-ca-key.pem -config=/vagrant/config/cfssl.json \
    -hostname="localhost,127.0.0.1" - | cfssljson -bare server
