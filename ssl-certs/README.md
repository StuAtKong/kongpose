# Generate Private CA certificates

To ease generation of certificates for testing, we will use the smallstep docker image;

https://smallstep.com/docs/step-cli/basic-crypto-operations


## Generate Private CA key and certificate

### Create a template file for the Root CA generation (root.tpl);

```
{
    "subject": {{ toJson .Subject }},
    "issuer": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 2
    }
}
```

### Create the Root CA using the template

Make certificate expiry 5 years (43830 hours)

)
```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create --template /tmp/root.tpl --not-after=43830h --no-password --insecure "Demo Kong Root CA" /tmp/root_ca.pem /tmp/root_ca.key
```

## Generate Intermediate CA SSL/TLS Certificates

### Create a template file for the 1st Intermediate CA generation (intermediate1.tpl);

```
{
    "subject": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 1
    }
}
```

### Create the 1st Intermediate CA using the template

Make certificate expiry 1 year (8766 hours)

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create --template /tmp/intermediate1.tpl --not-after=8766h --ca /tmp/root_ca.pem --ca-key /tmp/root_ca.key --no-password --insecure "Demo Kong Root Intermediate1 CA" /tmp/intermediate_ca1.pem /tmp/intermediate_ca1.key
```

### Create the 2nd Intermediate CA signed by the first Intermediate CA

Make certificate expiry 6 months (4383 hours)

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create --profile intermediate-ca --ca /tmp/intermediate_ca1.pem --ca-key /tmp/intermediate_ca1.key --not-after=4383h --no-password --insecure "Demo Kong Root Intermediate2 CA" /tmp/intermediate_ca2.pem /tmp/intermediate_ca2.key
```

## Generate the server SSL certificates

### Generate a certificate for Kong named endpoints (Manager, Admin API, Portal, Portal API and Proxy)

Make certificate expiry 6 months (4383 hours)

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create manager.kong.lan /tmp/kong.lan.pem /tmp/kong.lan.key \
--san api.kong.lan \
--san portal.kong.lan \
--san portal-api.kong.lan \
--san proxy.kong.lan \
--profile leaf \
--not-after=4383h \
--no-password \
--insecure \
--ca /tmp/intermediate_ca2.pem \
--ca-key /tmp/intermediate_ca2.key \
--bundle
```

### Generate a certificate for client MTLS connections (hostname: client.kong.lan)

Make certificate expiry 6 months (4383 hours)

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create client.kong.lan /tmp/client.kong.lan.pem /tmp/client.kong.lan.key \
--profile leaf \
--not-after=4383h \
--no-password \
--insecure \
--ca /tmp/intermediate_ca2.pem \
--ca-key /tmp/intermediate_ca2.key \
--bundle
```

### Generate a wildcard certificate for *.kong.lan for general use

Make certificate expiry 6 months (4383 hours)

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create '*.kong.lan' /tmp/wild.kong.lan.pem /tmp/wild.kong.lan.key \
--profile leaf \
--not-after=4383h \
--no-password \
--insecure \
--ca /tmp/intermediate_ca2.pem \
--ca-key /tmp/intermediate_ca2.key \
--bundle
```

### Create certificate for Mutual TLS consumer signed by Intermediate2

Make certificate expiry 6 months (4383 hours)

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create 'mtls-consumer' /tmp/client/mtls-consumer.kong.lan.pem /tmp/client/mtls-consumer.kong.lan.key \
--profile leaf \
--not-after=4383h \
--no-password \
--insecure \
--ca /tmp/intermediate_ca2.pem \
--ca-key /tmp/intermediate_ca2.key \
--bundle
```

### Create a certificate bundle to be used with HA proxy

HA proxy also references a bundled certificate located at: ssl-certs/smallstep/combined-wild.pem this will need to be replaced with a bundle of the certs you just generated, they can be concatenated with the following command:

```
cat ssl-certs/smallstep/wild.kong.lan.pem ssl-certs/smallstep/intermediate_ca2.pem ssl-certs/smallstep/intermediate_ca1.pem ssl-certs/smallstep/root_ca.pem ssl-certs/smallstep/wild.kong.lan.key > ssl-certs/smallstep/combined-wild.pem
```

### Validating certificates and trusting them

You can check the generated certificate like this;

```
$ openssl x509 -text -in smallstep/kong.lan.pem
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            58:9b:42:4b:55:37:a0:d2:36:4d:6c:d2:bc:11:18:a2
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = Kong Intermediate CA 2
        Validity
            Not Before: Feb 22 15:52:00 2022 GMT
            Not After : Feb 22 15:52:00 2023 GMT
        Subject: CN = manager.kong.lan
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:25:35:a5:9c:3b:69:06:3e:0d:63:5e:43:44:28:
                    99:13:77:32:d9:59:d5:3f:aa:0a:45:89:30:96:0b:
                    84:91:a5:68:df:3b:78:1e:e6:4e:f6:66:51:91:d9:
                    f5:47:52:eb:90:04:de:2b:92:2d:c6:65:5e:b8:bc:
                    cf:4d:7c:3a:63
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage:
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier:
                CC:7B:5D:2B:C2:DF:4A:06:81:2F:F4:D1:12:24:C9:6C:D3:24:3A:94
            X509v3 Authority Key Identifier:
                keyid:4C:EF:7B:3A:C4:51:FA:38:6C:91:3A:1C:C0:D4:DE:46:FB:C1:E9:13

            X509v3 Subject Alternative Name:
                DNS:api.kong.lan, DNS:proxy.kong.lan, DNS:portal.kong.lan, DNS:portal-api.kong.lan
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:21:00:d1:2e:d3:ce:5f:78:76:6b:9b:eb:b6:51:b1:
         c8:1e:32:4e:f2:04:2a:cf:96:fc:7f:60:75:3b:9b:ce:e9:7e:
         56:02:20:5a:0c:f3:94:f3:c4:45:80:c9:6e:ca:77:74:23:9c:
         0a:f3:3a:4a:0e:9a:1d:54:51:68:10:69:5b:5a:8c:20:40
-----BEGIN CERTIFICATE-----
MIIB/DCCAaKgAwIBAgIQWJtCS1U3oNI2TWzSvBEYojAKBggqhkjOPQQDAjAhMR8w
HQYDVQQDExZLb25nIEludGVybWVkaWF0ZSBDQSAyMB4XDTIyMDIyMjE1NTIwMFoX
DTIzMDIyMjE1NTIwMFowGzEZMBcGA1UEAxMQbWFuYWdlci5rb25nLmxhbjBZMBMG
ByqGSM49AgEGCCqGSM49AwEHA0IABCU1pZw7aQY+DWNeQ0QomRN3MtlZ1T+qCkWJ
MJYLhJGlaN87eB7mTvZmUZHZ9UdS65AE3iuSLcZlXri8z018OmOjgcEwgb4wDgYD
VR0PAQH/BAQDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNV
HQ4EFgQUzHtdK8LfSgaBL/TREiTJbNMkOpQwHwYDVR0jBBgwFoAUTO97OsRR+jhs
kTocwNTeRvvB6RMwTQYDVR0RBEYwRIIMYXBpLmtvbmcubGFugg5wcm94eS5rb25n
LmxhboIPcG9ydGFsLmtvbmcubGFughNwb3J0YWwtYXBpLmtvbmcubGFuMAoGCCqG
SM49BAMCA0gAMEUCIQDRLtPOX3h2a5vrtlGxyB4yTvIEKs+W/H9gdTubzul+VgIg
WgzzlPPERYDJbsp3dCOcCvM6Sg6aHVRRaBBpW1qMIEA=
-----END CERTIFICATE-----
```

Notice the SAN in the certificate;

```
            X509v3 Subject Alternative Name:
                DNS:api.kong.lan, DNS:proxy.kong.lan, DNS:portal.kong.lan, DNS:portal-api.kong.lan
```

The key files will have 640 permissions which will be a problem when using them in the docker image;

```
$ ll smallstep/kong.lan.key
-rw------- 1 stu stu 227 Feb 22 15:52 smallstep/kong.lan.key
```

*HACK Alert:* change the permissions to 644 to allow easy use in the docker container;

```
$ chmod 644 smallstep/*.key
$ chmod 644 smallstep/*.pem
```

## Add the private CA to the OS trustore

Browsers (Chrome, and others) will not allow access to sites using unknown CA certificates. To use the certificate for GUI functions, you will need to import the CA pem certificate to the truststore. For OSX, double click on the below pem file and make sure to trust the CA;

* root_ca.pem
* intermediate_ca1.pem
* intermediate_ca2.pem

![OSX keystore](/images/import-ca-cert.png)
