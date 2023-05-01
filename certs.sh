#!/bin/bash

#Preparing directory ~/ssl

mkdir /opt/ssl
cd /opt/ssl
mkdir -p {ca_root,ca1}/{pub,priv,newcerts}
echo 1000 > ca_root/serial
echo 1000 > ca1/serial
touch  {ca_root,ca1}/{index.txt,openssl.conf}
mkdir ca1/{csr,psk12}



echo "Generating CA certificate"
cat << EOF > ./ca_root/openssl.conf
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /opt/ssl/ca_root
certs             = /opt/ssl/ca_root/priv
#crl_dir           = /opt/ssl/ca_root/crl
new_certs_dir     = /opt/ssl/ca_root/newcerts
database          = /opt/ssl/ca_root/index.txt
serial            = /opt/ssl/ca_root/serial
RANDFILE          = /opt/ssl/ca_root/.rand

private_key       = /opt/ssl/ca_root/priv/ca.key
certificate       = /opt/ssl/ca_root/pub/ca.crt
default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = optional
organizationalUnitName  = optional
commonName              = optional
emailAddress            = optional


[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = RU
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
organizationName                = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

countryName_default             = RU
stateOrProvinceName_default     = Saint-Petersburg
localityName_default            = Saint-Petersburg
organizationName_default       = Local #EDITME

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

cd ./ca_root
openssl genrsa -aes256 -out priv/ca.key 4096
openssl req -config openssl.conf -key priv/ca.key -new -x509 -days 7300 -sha256 -extensions v3_ca -out pub/ca.crt



echo "Generating Intermediate certificate"
cat << EOF > /opt/ssl/ca1/openssl.conf
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /opt/ssl/ca1 # папка промежуточного цс
certs             = /opt/ssl/ca1/pub
new_certs_dir     = /opt/ssl/ca1/newcerts
database          = /opt/ssl/ca1/index.txt
serial            = /opt/ssl/ca1/serial
RANDFILE          = /opt/ssl/ca1/priv/.rand

private_key       = /opt/ssl/ca1/priv/ca1.key
certificate       = /opt/ssl/ca1/pub/ca1.crt

default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 365
preserve          = no
policy            = policy_loose
unique_subject = no


[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
organizationName                = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# значения по-умолчанию
countryName_default             = RU
stateOrProvinceName_default     = Saint-Petersburg
localityName_default            = Saint-Petersburg
organizationName_default       = Local #EDITME

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ usr_cert ]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName=DNS:sub.server.com,IP:10.10.10.10 #EDITME
EOF

cd ../ca1
openssl genrsa -aes256 -out priv/ca1.key 4096
openssl req -config openssl.conf -new -sha256 -key priv/ca1.key -out csr/ca1.csr
openssl ca -config ../ca_root/openssl.conf -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in csr/ca1.csr -out pub/ca1.crt



echo "Generating server certificate"
cd ../ca1
openssl genrsa -out priv/server.key 2048
openssl req -config openssl.conf -key priv/server.key -new -sha256 -out csr/server.csr
openssl ca -config openssl.conf -extensions server_cert -days 365 -notext -md sha256 -in csr/server.csr -out pub/server.crt
cat pub/ca1.crt ../ca_root/pub/ca.crt > pub/ca1_chain.crt
cat pub/server.crt pub/ca1_chain.crt > pub/server.crt



echo "Generating client certificate"
openssl genrsa -out priv/client1.key 2048
openssl req -config openssl.conf -key priv/client1.key -new -sha256 -out csr/client1.csr
openssl ca -config openssl.conf -extensions usr_cert -days 365 -notext -md sha256 -in csr/client1.csr -out pub/client1.crt
openssl pkcs12 -export -in pub/client1.crt -inkey priv/client1.key -certfile pub/ca1_chain.crt -out psk12/client1.p12 -passout pass:12344321


echo "Certificates are in /opt/ssl/. Move them to the "
echo "ssl_certificate /etc/nginx/ssl/server_chain.crt;"
echo "ssl_certificate_key /etc/nginx/ssl/server.lab.key;"
echo "ssl_client_certificate /etc/nginx/ssl/ca1_chain.crt;"
echo "ssl_verify_client on;"