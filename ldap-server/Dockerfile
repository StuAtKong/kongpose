FROM alpine:latest
VOLUME ./ldap-server:/tmp/setup-ad/ 

COPY setup.sh /tmp/setup.sh
RUN chmod 744 /tmp/setup-ad/setup.sh
RUN sh /tmp/setup-ad/setup.sh
 
COPY startup.sh /startup.sh
RUN chmod 744 /startup.sh
 
CMD ["samba -D"]
