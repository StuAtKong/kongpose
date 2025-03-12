# Generate Private CA key and certificate
#rm $(pwd)/ssl-certs/smallstep/root_ca.pem $(pwd)/ssl-certs/smallstep/root_ca.key
#docker run --rm \
#-v $(pwd)/ssl-certs/smallstep:/tmp \
#smallstep/step-cli step certificate create --template /tmp/root.tpl --not-after=43830h --no-password --insecure "Demo Kong Root CA" /tmp/root_ca.pem /tmp/root_ca.key

# Create the 1st Intermediate CA using the template
rm $(pwd)/ssl-certs/smallstep/intermediate_ca1.pem $(pwd)/ssl-certs/smallstep/intermediate_ca1.key
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create --template /tmp/intermediate1.tpl --not-after=8766h --ca /tmp/root_ca.pem --ca-key /tmp/root_ca.key --no-password --insecure "Demo Kong Root Intermediate1 CA" /tmp/intermediate_ca1.pem /tmp/intermediate_ca1.key

# Create the 2nd Intermediate CA signed by the first Intermediate CA
rm $(pwd)/ssl-certs/smallstep/intermediate_ca2.pem $(pwd)/ssl-certs/smallstep/intermediate_ca2.key
docker run --rm \
-v $(pwd)/ssl-certs/smallstep:/tmp \
smallstep/step-cli step certificate create --profile intermediate-ca --ca /tmp/intermediate_ca1.pem --ca-key /tmp/intermediate_ca1.key --not-after=4383h --no-password --insecure "Demo Kong Root Intermediate2 CA" /tmp/intermediate_ca2.pem /tmp/intermediate_ca2.key

# Generate a certificate for Kong named endpoints (Manager, Admin API, Portal, Portal API and Proxy)
rm $(pwd)/ssl-certs/smallstep/kong.lan.pem $(pwd)/ssl-certs/smallstep/kong.lan.key
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

# Generate a certificate for client MTLS connections (hostname: client.kong.lan)
rm $(pwd)/ssl-certs/smallstep/client.kong.lan.pem $(pwd)/ssl-certs/smallstep/client.kong.lan.key
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

# Generate a wildcard certificate for *.kong.lan for general use
rm $(pwd)/ssl-certs/smallstep/wild.kong.lan.pem $(pwd)/ssl-certs/smallstep/wild.kong.lan.key
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

# Create certificate for Mutual TLS consumer signed by Intermediate2
rm $(pwd)/ssl-certs/smallstep/client/mtls-consumer.kong.lan.pem $(pwd)/ssl-certs/smallstep/client/mtls-consumer.kong.lan.key
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

# Create a certificate bundle to be used with HA proxy
cat ssl-certs/smallstep/wild.kong.lan.pem ssl-certs/smallstep/intermediate_ca2.pem ssl-certs/smallstep/intermediate_ca1.pem ssl-certs/smallstep/root_ca.pem ssl-certs/smallstep/wild.kong.lan.key > ssl-certs/smallstep/combined-wild.pem

# Hacky permissions
chmod 644 $(pwd)/ssl-certs/smallstep/*.key
chmod 644 $(pwd)/ssl-certs/smallstep/*.pem
