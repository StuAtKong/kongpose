# Generate Private CA certificates

## Generate Private CA key and certificate


```
$ openssl genrsa -des3 -out rootCA.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
....................................+++++
.....+++++
e is 65537 (0x010001)
Enter pass phrase for rootCA.key:
Verifying - Enter pass phrase for rootCA.key:
```

CA certificate validity is set to 1024 days (3 years)

```
$ openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024  -out rootCA.pem
Enter pass phrase for rootCA.key:
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
Common Name (e.g. server FQDN or YOUR name) []:Support Root CA
Email Address []:stu@konghq.com
```

## Generate SSL/TLS Certificates

We will be using the hostname api.kong.lan so need to create a certificate for this host. Setup the configuration for an X509 v3 certificate (this has SAN information which is now required)

```
cat > v3.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = api.kong.lan
DNS.2 = proxy.kong.lan
DNS.3 = client.kong.lan

EOF
```

Create a server private key for our kong server and a certificate signing request.

```
$ openssl req -new -nodes -out server.csr -newkey rsa:2048 -keyout server.key
Generating a RSA private key
..................................................................+++++
.......+++++
writing new private key to 'server.key'
-----
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
Common Name (e.g. server FQDN or YOUR name) []:api.kong.lan
Email Address []:stu@konghq.com

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

## Generate the server SSL certificate for api.kong.lan using rootCA.key, rootCA.pem and server.csr

```
$ openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 500 -sha256 -extfile v3.ext
Signature ok
subject=C = UK, ST = Hampshire, L = Aldershot, O = Kong UK, OU = Support, CN = api.kong.lan, emailAddress = stu@konghq.com
Getting CA Private Key
Enter pass phrase for rootCA.key:
```

You can check the generated certificate like this;

```
$ openssl x509 -in server.crt -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            02:eb:18:18:ff:41:c2:82:c5:14:02:5d:07:f8:d8:e9:e5:33:53:1f
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = UK, ST = Hampshire, L = Aldershot, O = Kong UK, OU = Support, CN = Support Root CA, emailAddress = stu@konghq.com
        Validity
            Not Before: Oct 30 12:13:18 2020 GMT
            Not After : Mar 14 12:13:18 2022 GMT
        Subject: C = UK, ST = Hampshire, L = Aldershot, O = Kong UK, OU = Support, CN = api.kong.lan, emailAddress = stu@konghq.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:d0:17:fb:5d:9b:47:87:fe:4f:61:59:c5:83:5d:
                    24:e4:ee:79:a1:5a:f0:bf:7d:81:7e:55:cb:bb:bb:
                    3f:ed:ca:bc:89:57:27:e4:32:93:19:99:86:9d:73:
                    72:9b:f3:72:5e:c8:e6:4b:6d:00:9c:99:9e:70:04:
                    64:66:b2:33:ed:b7:c2:e8:4a:5e:bb:15:63:14:9b:
                    0b:ad:6e:74:cf:cd:17:72:7f:93:12:3d:24:a7:89:
                    13:e2:20:cf:29:11:99:72:3b:3c:66:2c:8f:50:40:
                    fa:0d:48:3f:48:33:67:58:57:7b:4c:66:11:3c:ef:
                    d2:ac:9e:a2:5d:cf:4f:36:94:fa:a9:8d:8d:bb:4a:
                    f8:39:7f:f2:c7:c2:ac:91:25:8b:8f:86:00:5d:98:
                    68:5b:54:3a:66:21:50:8f:1a:4a:8d:f4:6b:6f:be:
                    2d:53:a2:0f:b0:9a:a5:8b:0e:17:8f:ed:f2:81:26:
                    de:b1:4a:63:cc:e7:22:76:84:2b:28:96:dc:eb:27:
                    53:51:5e:2d:aa:e7:dc:b4:8c:40:0f:75:39:d1:42:
                    6a:e7:df:c1:d5:c2:81:0e:28:66:c2:02:d7:c7:0f:
                    4d:d5:9e:bb:2b:9d:63:29:fd:09:ad:6a:e3:29:be:
                    b2:27:04:9a:3e:10:c1:2c:d3:08:44:10:fb:a1:2f:
                    de:e3
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Authority Key Identifier:
                keyid:76:C9:29:7F:4C:09:45:0C:63:B7:34:05:65:C8:96:99:47:E5:D9:B7

            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Key Usage:
                Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment
            X509v3 Subject Alternative Name:
                DNS:api.kong.lan
    Signature Algorithm: sha256WithRSAEncryption
         0a:a7:5c:43:4a:93:38:13:ab:3a:87:5f:df:05:01:9a:88:0a:
         4f:84:21:21:87:e4:ef:1b:f5:ff:e2:f9:7a:6a:95:97:ef:3f:
         e7:48:8d:b1:6c:ea:12:11:23:fb:92:0e:d0:7e:64:0b:3e:cd:
         96:d8:ff:f1:00:c3:67:02:b0:5a:9e:74:7d:e4:ba:22:f9:ba:
         7d:cd:3d:a6:70:b9:c3:16:ab:10:03:be:cf:c0:51:68:9c:04:
         84:59:75:ca:b8:90:e1:e1:7b:c7:c4:f1:2c:8a:6d:8a:12:ee:
         b7:13:9c:b2:94:c5:72:33:e8:c6:00:9a:a3:b8:2d:34:7e:fc:
         4a:ac:55:bb:50:b8:11:4d:a4:78:41:73:55:09:d1:58:89:04:
         b0:1c:90:19:11:98:31:f6:bb:31:76:6d:84:1b:18:09:da:5f:
         08:d5:fb:2d:fb:79:fd:ab:cb:1e:77:56:05:24:77:b4:17:65:
         8b:89:39:36:4f:ef:af:18:24:36:c1:ad:f5:16:dd:f5:10:b4:
         c5:b5:b0:35:81:ed:0b:b6:8c:05:26:74:f1:48:26:4c:d3:12:
         fa:16:2f:07:37:5e:bf:59:59:b3:25:ef:0d:78:19:ad:6d:bb:
         a2:5f:97:f0:be:27:d9:34:65:f5:49:7a:bb:2e:6d:77:0c:2a:
         d7:a6:e6:3b
-----BEGIN CERTIFICATE-----
MIIEBTCCAu2gAwIBAgIUAusYGP9BwoLFFAJdB/jY6eUzUx8wDQYJKoZIhvcNAQEL
BQAwgZIxCzAJBgNVBAYTAlVLMRIwEAYDVQQIDAlIYW1wc2hpcmUxEjAQBgNVBAcM
CUFsZGVyc2hvdDEQMA4GA1UECgwHS29uZyBVSzEQMA4GA1UECwwHU3VwcG9ydDEY
MBYGA1UEAwwPU3VwcG9ydCBSb290IENBMR0wGwYJKoZIhvcNAQkBFg5zdHVAa29u
Z2hxLmNvbTAeFw0yMDEwMzAxMjEzMThaFw0yMjAzMTQxMjEzMThaMIGPMQswCQYD
VQQGEwJVSzESMBAGA1UECAwJSGFtcHNoaXJlMRIwEAYDVQQHDAlBbGRlcnNob3Qx
EDAOBgNVBAoMB0tvbmcgVUsxEDAOBgNVBAsMB1N1cHBvcnQxFTATBgNVBAMMDGFw
aS5rb25nLmxhbjEdMBsGCSqGSIb3DQEJARYOc3R1QGtvbmdocS5jb20wggEiMA0G
CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQF/tdm0eH/k9hWcWDXSTk7nmhWvC/
fYF+Vcu7uz/tyryJVyfkMpMZmYadc3Kb83JeyOZLbQCcmZ5wBGRmsjPtt8LoSl67
FWMUmwutbnTPzRdyf5MSPSSniRPiIM8pEZlyOzxmLI9QQPoNSD9IM2dYV3tMZhE8
79KsnqJdz082lPqpjY27Svg5f/LHwqyRJYuPhgBdmGhbVDpmIVCPGkqN9Gtvvi1T
og+wmqWLDheP7fKBJt6xSmPM5yJ2hCsoltzrJ1NRXi2q59y0jEAPdTnRQmrn38HV
woEOKGbCAtfHD03VnrsrnWMp/QmtauMpvrInBJo+EMEs0whEEPuhL97jAgMBAAGj
VDBSMB8GA1UdIwQYMBaAFHbJKX9MCUUMY7c0BWXIlplH5dm3MAkGA1UdEwQCMAAw
CwYDVR0PBAQDAgTwMBcGA1UdEQQQMA6CDGFwaS5rb25nLmxhbjANBgkqhkiG9w0B
AQsFAAOCAQEACqdcQ0qTOBOrOodf3wUBmogKT4QhIYfk7xv1/+L5emqVl+8/50iN
sWzqEhEj+5IO0H5kCz7Nltj/8QDDZwKwWp50feS6Ivm6fc09pnC5wxarEAO+z8BR
aJwEhFl1yriQ4eF7x8TxLIptihLutxOcspTFcjPoxgCao7gtNH78SqxVu1C4EU2k
eEFzVQnRWIkEsByQGRGYMfa7MXZthBsYCdpfCNX7Lft5/avLHndWBSR3tBdli4k5
Nk/vrxgkNsGt9Rbd9RC0xbWwNYHtC7aMBSZ08UgmTNMS+hYvBzdev1lZsyXvDXgZ
rW27ol+X8L4n2TRl9Ul6uy5tdwwq16bmOw==
-----END CERTIFICATE-----
```

Notice the SAN in the certificate;

```
            X509v3 Subject Alternative Name:
                DNS:api.kong.lan
```

The key files will have 640 permissions which will be a problem when using them in the docker image;

```
$ ll server.key
total 44
-rw------- 1 stu stu 1704 Oct 30 12:10 server.key
```

*HACK Alert:* change the permissions to 644 to allow easy use in the docker container;

```
$ chmod 644 server.key
```

## Add the private CA to the OS trustore

This step is optional-ish. It is not required but some browsers (Chrome, and others) will not allow access to sites using unknown CA certificates. To use the certificate for GUI functions, you will need to import the rootCA.pem certificate to the truststore. For OSX, double click on the rootCA.pem file and make sure to trust the CA;

![OSX keystore](/images/import-ca-cert.png)
