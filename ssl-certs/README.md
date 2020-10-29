# Generate Private CA certificates

## Generate Private CA key and certificate


```
$ openssl genrsa -out ca.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
..........................+++++
................................................+++++
e is 65537 (0x010001)
$
```

CA certificate validity is set to 1825 days (5 years)

```
$ openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825 -out ca.crt
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
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Kong Support UK
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:
Email Address []:stu@konghq.com
$
```

## Generate SSL/TLS Certificates

Create a server private key for our kong server.

```
$ openssl genrsa -out server.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
.......................................................+++++
......+++++
e is 65537 (0x010001)
```

Now we need to generate a Certificate Signing Request (csr). This is most easily done by creating a csr.conf like this, assuming that we are creating a certificate for api.kong.lan;

```
cat > csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = UK
ST = Hampshire
L = Aldershot
O = Kong Support UK
OU = Stu Support Silo
CN = api.kong.lan

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = api.kong.lan

EOF
```

Generate the CSR using the private key for the server and the CSR config file.

```
$ openssl req -new -key server.key -out server.csr -config csr.conf
```

## Generate the server SSL certificate for api.kong.lan using ca.key, ca.crt and server.csr

```
$ openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
> -CAcreateserial -out server.crt -days 10000 \
> -extfile csr.conf
Signature ok
subject=C = UK, ST = Hampshire, L = Aldershot, O = Kong Support UK, OU = Stu Support Silo, CN = api.kong.lan
Getting CA Private Key
```

You can check the generated certificate like this;

```
$ openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
> -CAcreateserial -out server.crt -days 10000 \
> -extfile csr.conf
Signature ok
subject=C = UK, ST = Hampshire, L = Aldershot, O = Kong Support UK, OU = Stu Support Silo, CN = api.kong.lan
Getting CA Private Key
stu@mrdizzy:~/kongpose/ssl-certs$ openssl x509 -in server.crt -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            59:f3:f8:5e:e6:6d:88:4c:77:31:25:f3:8b:a6:16:47:54:96:ca:f5
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = UK, ST = Hampshire, L = Aldershot, O = Kong Support UK, emailAddress = stu@konghq.com
        Validity
            Not Before: Oct 29 16:35:47 2020 GMT
            Not After : Mar 16 16:35:47 2048 GMT
        Subject: C = UK, ST = Hampshire, L = Aldershot, O = Kong Support UK, OU = Stu Support Silo, CN = api.kong.lan
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:ca:cf:a9:97:fe:6e:25:25:19:45:fc:48:00:ff:
                    0d:93:71:78:8f:c7:5c:c6:94:21:65:e3:e0:e1:d0:
                    fa:46:f3:7f:7a:e0:d0:71:db:54:25:30:a1:ce:e8:
                    de:22:28:f6:fc:6c:5a:2d:9b:64:35:cb:83:17:e9:
                    dd:33:00:5f:a9:0a:16:19:a4:7d:bb:b2:18:89:fa:
                    11:bc:0b:ff:6b:36:15:c2:74:e3:90:ab:3c:d3:31:
                    89:dd:de:82:4d:e1:7e:97:88:16:f4:ce:08:36:e9:
                    c0:09:c7:a7:f3:ea:2a:9c:9a:7d:ce:23:16:f8:1a:
                    00:b3:63:0d:2d:67:1c:74:76:b3:ef:d0:09:f8:a9:
                    1b:e9:a5:88:af:77:ce:30:d1:58:65:1b:9e:d2:3f:
                    3f:e2:21:31:7f:79:44:05:3b:ae:d0:ef:a7:28:dc:
                    e8:67:3c:aa:79:fd:0f:cc:61:e1:25:b3:76:72:21:
                    89:9b:99:e3:78:95:0f:5e:41:d8:27:41:e2:b7:e9:
                    db:6a:25:fd:23:0e:01:f4:6f:31:c2:e3:9b:12:7b:
                    65:43:75:57:08:00:39:c9:7d:08:07:ca:26:ad:fd:
                    05:00:52:14:76:7a:72:5f:d8:b8:71:5e:09:49:d6:
                    7b:d0:50:55:d3:a9:1d:bb:8f:21:75:36:66:4f:03:
                    de:1d
                Exponent: 65537 (0x10001)
    Signature Algorithm: sha256WithRSAEncryption
         4d:32:70:00:d7:b9:30:22:48:5b:b5:38:99:2f:2e:47:ff:8a:
         45:7e:bb:23:89:53:48:a6:05:12:a8:cc:a8:41:34:08:c5:36:
         1c:5d:d7:c0:73:d5:d2:13:1b:4f:aa:04:1e:dd:bc:f7:a0:54:
         0a:7c:30:5b:67:26:c8:4b:e5:13:9a:80:b8:e6:58:11:a5:b1:
         77:4f:53:d0:7f:0e:44:60:e7:53:02:bf:ff:3f:ac:fc:88:ab:
         ec:51:2c:4d:0b:de:44:b4:95:0c:30:98:a0:66:81:63:36:c2:
         dd:10:62:c7:1c:38:41:c2:68:54:f0:3e:b1:1a:7d:60:52:38:
         1e:d6:27:b6:cc:4e:c9:3f:ce:35:29:15:96:f6:7a:6c:03:e1:
         ec:6b:bf:6b:3b:e0:c3:7b:67:07:7b:61:12:6e:4f:7f:72:d7:
         ed:33:2f:82:8e:72:47:1d:3e:fd:3a:06:74:44:f9:b3:79:00:
         97:34:90:58:a8:d7:5a:37:db:4f:e1:39:a1:6b:8a:3a:6f:7f:
         6c:1b:c2:30:4a:f9:9c:f6:a2:7e:d1:4c:67:99:52:e9:ae:af:
         eb:25:f5:c0:34:6a:fd:b4:e7:5c:2d:ff:bb:86:c4:00:9f:ef:
         c9:4c:a0:a7:b3:c5:9b:8a:29:aa:52:e4:51:a0:3d:35:cf:2b:
         92:e3:ca:84
-----BEGIN CERTIFICATE-----
MIIDfDCCAmSgAwIBAgIUWfP4XuZtiEx3MSXzi6YWR1SWyvUwDQYJKoZIhvcNAQEL
BQAwbjELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUhhbXBzaGlyZTESMBAGA1UEBwwJ
QWxkZXJzaG90MRgwFgYDVQQKDA9Lb25nIFN1cHBvcnQgVUsxHTAbBgkqhkiG9w0B
CQEWDnN0dUBrb25naHEuY29tMB4XDTIwMTAyOTE2MzU0N1oXDTQ4MDMxNjE2MzU0
N1owgYExCzAJBgNVBAYTAlVLMRIwEAYDVQQIDAlIYW1wc2hpcmUxEjAQBgNVBAcM
CUFsZGVyc2hvdDEYMBYGA1UECgwPS29uZyBTdXBwb3J0IFVLMRkwFwYDVQQLDBBT
dHUgU3VwcG9ydCBTaWxvMRUwEwYDVQQDDAxhcGkua29uZy5sYW4wggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDKz6mX/m4lJRlF/EgA/w2TcXiPx1zGlCFl
4+Dh0PpG83964NBx21QlMKHO6N4iKPb8bFotm2Q1y4MX6d0zAF+pChYZpH27shiJ
+hG8C/9rNhXCdOOQqzzTMYnd3oJN4X6XiBb0zgg26cAJx6fz6iqcmn3OIxb4GgCz
Yw0tZxx0drPv0An4qRvppYivd84w0VhlG57SPz/iITF/eUQFO67Q76co3OhnPKp5
/Q/MYeEls3ZyIYmbmeN4lQ9eQdgnQeK36dtqJf0jDgH0bzHC45sSe2VDdVcIADnJ
fQgHyiat/QUAUhR2enJf2LhxXglJ1nvQUFXTqR27jyF1NmZPA94dAgMBAAEwDQYJ
KoZIhvcNAQELBQADggEBAE0ycADXuTAiSFu1OJkvLkf/ikV+uyOJU0imBRKozKhB
NAjFNhxd18Bz1dITG0+qBB7dvPegVAp8MFtnJshL5ROagLjmWBGlsXdPU9B/DkRg
51MCv/8/rPyIq+xRLE0L3kS0lQwwmKBmgWM2wt0QYsccOEHCaFTwPrEafWBSOB7W
J7bMTsk/zjUpFZb2emwD4exrv2s74MN7Zwd7YRJuT39y1+0zL4KOckcdPv06BnRE
+bN5AJc0kFio11o320/hOaFrijpvf2wbwjBK+Zz2on7RTGeZUumur+sl9cA0av20
51wt/7uGxACf78lMoKezxZuKKapS5FGgPTXPK5LjyoQ=
-----END CERTIFICATE-----
```

