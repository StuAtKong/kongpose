# Create a client cert for mutual-tls auth here

Create a client cert for mutual-tls auth here

## Create the client key

```
$ openssl genrsa -out client.key 4096
Generating RSA private key, 4096 bit long modulus (2 primes)
........................................................++++
.........................................................................................++++
e is 65537 (0x010001)
```

## Create the client signing request

Note, the CN value is set to `mtls-consumer` which will match the consumer defined in Kong.

```
$ openssl req -new -key client.key -out client.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:UK
State or Province Name (full name) [Some-State]:Hampshire
Locality Name (eg, city) []:Aldershot
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Kong UK
Organizational Unit Name (eg, section) []:Support
Common Name (e.g. server FQDN or YOUR name) []:mtls-consumer
Email Address []:stu@konghq.com

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

## Create the openssl configuration file

```
cat > client_cert_ext.conf <<EOF
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
EOF
```

## Create the client certificate

```
$ openssl x509 -req -in client.csr -CA ../rootCA.pem -CAkey ../rootCA.key -out client.pem -CAcreateserial -days 365 -sha256 -extfile client_cert_ext.conf
```

