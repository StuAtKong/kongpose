# Create a client cert for mutual-tls auth here

Create a client cert for mutual-tls auth here

```
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create 'mtls-consumer' /tmp/client/mtls-consumer.kong.lan.pem /tmp/client/mtls-consumer.kong.lan.key \
--profile leaf \
--not-after=8760h \
--no-password \
--insecure \
--ca /tmp/intermediate_ca2.pem \
--ca-key /tmp/intermediate_ca2.key \
--bundle
```

## Create a cfx file from the pem/key file

```
openssl pkcs12 -export -out ssl-certs/smallstep/client.pfx -inkey ssl-certs/smallstep/client/mtls-consumer.kong.lan.key -in ssl-certs/smallstep/client/mtls-consumer.kong.lan.pem -certfile ssl-certs/smallstep/intermediate_ca2.pem
```

