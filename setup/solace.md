# Solace Broker

This example will configure a Solace broker to allow  Kong to publish messages

# Contents
 - [Concepts](#concepts)
 - [Setup the Solace Broker](#solace-broker-setup)
 - [Kong setup](#kong-setup)
 - [Get the Solace TryMe! tool]()
 - [Send a request](#send-a-request)
 - [Start the Solace CLI]()

## Concepts

### topic
a topic is not a managed object in Solace i.e. you do not need to create anything to send a message to a topic. A topic is actually a string property that is attached to the Solace message itself (topics are considered ephemeral metadata rather than an actual Solace entity). There is no "buffer" or "history" for a topic and if there are no subscribers to the topic, the message is lost (it is possible to create a queue that is subscribed to a topic to keep messages, but let's [KISS](https://en.wikipedia.org/wiki/KISS_principle) for now)

### queue
A Queue is a named, managed object on the broker that provides Guaranteed Delivery (Persistence).

### vpn

A Message VPN is a logical partition of a single Solace broker. queues and topics must be unique in a VPN but can have the same name in different vpn's

## Solace Broker Setup

Start the solace server using the docker-compose service

~~~
docker compose up -d solace
~~~

This will provide a GUI for Solace Admin;

Open the Solace web GUI and login with the username and password of `admin/admin`

[https://solace.kong.lan](https://solace.kong.lan)

## Kong Setup

There is a single Route/Plugin in the kongposer setup that will forward the HTTP request to a Solace topic. The plugin is configured to send message to a Solace topic named `kong`. It will also remove headers named `x-test` from the message sent to Solace

~~~
config:
name: solace-upstream
  message:
    functions:
      - message.headers["x-test"] = nil return message
    forward_body: true
    ttl: 0
    forward_headers: true
    forward_method: true
    tracing_sampled: false
    default_content: null
    priority: 4
    delivery_mode: PERSISTENT
    dmq_eligible: false
    sender_id: kong
    ack_timeout: 2000
    tracing: true
    forward_uri: true
    destinations:
      - name: kong
        type: TOPIC
  session:
    properties: {}
    host: tcp://solace:55555
    ssl_validate_certificate: false
    vpn_name: default
    authentication:
      scheme: BASIC
      id_token_header: null
      access_token_header: null
      password: admin
      username: admin
      access_token: null
      id_token: null
    connect_timeout: 3000
~~~



## Get the Solace TryMe! tool

This will allow you to subscribe to topics/queues and see messages as they arrive

~~~
https://docs.solace.com/Get-Started/tutorial/try-me-cli-tool.htm#linux-or-wsl-on-windows-using-apt-get
~~~

and start listening to the kong topic

~~~
stm config init
stm manage connection --url ws://localhost:8008 --vpn default --username admin --password admin
stm receive --vpn default -t kong
~~~

You should receive output similar to this;

~~~
$ stm receive --vpn default -t kong

█████╗ █████╗ ██╗    ████╗  ████╗████╗  ████████╗█████╗ ██╗   ██╗    ███╗  ███╗█████╗
█╔═══╝██╔══██╗██║   ██╔═██╗██╔══╝██══╝  ╚══██╔══╝██╔═██╗╚██╗ ██╔╝    ████╗ ███║██╔══╝
█████╗██║  ██║██║   ██████║██║   ███╗      ██║   █████╔╝ ╚████╔╝     ██╔███╔██║███╗  
╚══██║██║  ██║██║   ██╔═██║██║   ██╔╝      ██║   ██╔═██╗  ╚██╔╝ ███  ██║╚██╝██║██╔╝  
█████║╚█████╔╝█████╗██║ ██║╚████╗████╗     ██║   ██║ ██║   ██║       ██║ ╚╝ ██║█████╗
╚════╝ ╚════╝ ╚════╝╚═╝ ╚═╝ ╚═══╝╚═══╝     ╚═╝   ╚═╝ ╚═╝   ╚═╝       ╚═╝    ╚═╝╚════╝
v0.0.81 - https://github.com/SolaceLabs/solace-tryme-cli

ℹ  info      info: loading 'receive' command from configuration '/home/cre/.stm/stm-cli-config.json'
…  waiting   connecting to broker [ws://localhost:8008, vpn: default, username: kong-user, password: ******]
✔  success   success: === stm_recv_de7af1e3 successfully connected and ready to receive events. ===
ℹ  info      info: subscribing to kong
ℹ  info      info: press Ctrl-C to exit
✔  success   success: successfully subscribed to topic: kong
~~~

## Send a Request

Send a plain text request to Solace via Kong

~~~
curl -X POST http://proxy.kong.lan/solace/anything -H 'Content-Type: text/plain' -d '"This is a text test message"'
~~~

Send a json request to Solace via Kong

~~~
curl -X POST http://proxy.kong.lan/solace/anything -H "x-test:abc" -H 'Content-Type: application/json' -d '{"message":"This is json test message"}'
~~~

If you check the Solace Try-me tool, then you should see the messages from Kong;

~~~
waiting   1 receiving message [01/14/2026, 16:38:40.891]
✔  success   success: received BINARY message on topic [Topic kong]
ℹ  info      message: Destination: [Topic kong]
ℹ  info      message: Payload
{
  "body": "\"This is a text test message\"",
  "headers": {
    "x-forwarded-for": "10.1.1.12",
    "user-agent": "curl/7.81.0",
    "content-type": "text/plain",
    "x-forwarded-host": "proxy.kong.lan",
    "host": "proxy.kong.lan",
    "content-length": "29",
    "accept": "*/*"
  },
  "body_args": [],
  "method": "POST",
  "uri_args": [],
  "uri": "/solace/anything"
}
…  waiting   2 receiving message [01/14/2026, 16:38:48.271]
✔  success   success: received BINARY message on topic [Topic kong]
ℹ  info      message: Destination: [Topic kong]
ℹ  info      message: Payload
{
  "body": "{\"message\":\"This is json test message\"}",
  "headers": {
    "x-forwarded-for": "10.1.1.12",
    "x-forwarded-host": "proxy.kong.lan",
    "user-agent": "curl/7.81.0",
    "content-type": "application/json",
    "content-length": "39",
    "host": "proxy.kong.lan",
    "accept": "*/*"
  },
  "body_args": {
    "message": "This is json test message"
  },
  "method": "POST",
  "uri_args": [],
  "uri": "/solace/anything"
}
~~~


## Start the Solace CLI

~~~
docker compose exec -it solace /usr/sw/loads/currentload/bin/cli -Ad/bin/cli -A
~~~

To see clients connected to Solace;

~~~
show client *
~~~

~~~
Primary Virtual Router:

Client Name                   # Subs Message VPN      Description
--------------------------- -------- ---------------- ------------------------
0514c6314604/2638/00000001/        1 default          
  r4Im1MyB9P                                          
0514c6314604/2639/00000001/        1 default          
  4twVYEJEzx                                          
0514c6314604/2640/00000001/        1 default          
  gyVlstICdW                                          
stm_recv_de7af1e3                  2 default          Receive application crea
                                                        ted via Solace Try-Me 
                                                        CLI


Internal Virtual Router:

Client Name                   # Subs Message VPN      Description
--------------------------- -------- ---------------- ------------------------
#client                            6 default          Internal Message Bus
~~~

We can see there are 4 clients, one is the try-me too and the other 3 in this example are the Kong workers

We might want to disconnet the Kong workers to force them to reconnect;

~~~
enable
admin
client 0514c6314604/2638/00000001/r4Im1MyB9P message-vpn default
disconnect
exit
client 0514c6314604/2639/00000001/4twVYEJEzx message-vpn default
disconnect
exit
client 0514c6314604/2640/00000001/gyVlstICdW message-vpn default
disconnect
exit
~~~

If you check the clients, you should now only see the try-me utility;

~~~
# show client *

Primary Virtual Router:

Client Name                   # Subs Message VPN      Description
--------------------------- -------- ---------------- ------------------------
stm_recv_de7af1e3                  2 default          Receive application crea
                                                        ted via Solace Try-Me 
                                                        CLI


Internal Virtual Router:

Client Name                   # Subs Message VPN      Description
--------------------------- -------- ---------------- ------------------------
#client                            6 default          Internal Message Bus
~~~

This might break Kong though as it will not know the connection has closed ;-)

## Locust example

Using the Locust utility, we can simulate load on Kong to send multiple messages. The `locustfile.py` script could look like this;

~~~
import uuid  # Added for unique ID generation
from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    wait_time = between(0.5, 1)
    host = "http://proxy.kong.lan"

    @task
    def post_solace_message(self):
        # Generate a unique string for this specific request
        unique_id = str(uuid.uuid4())

        headers = {
            "x-test": f"abc-{unique_id}", # Unique header: e.g., abc-550e8400-e29b...
            "Content-Type": "application/json"
        }
        
#        payload = {
#            "message": "This is json test message",
#            "request_id": unique_id  # Often helpful to include in the body too
#        }

        payload = {
            "request_id": unique_id,  # Often helpful to include in the body too
            "teamName": "managed-service-apim",
            "environment": "dev",
            "serviceName": "solace",
            "serviceDescription": "Solace Service for API Management",
            "systemMasterAbbreviation": "apig",
            "serviceVersion": "1.0.0"
        }

        with self.client.post(
            "/solace/anything", 
            json=payload, 
            headers=headers,
            catch_response=True
        ) as response:
            
            if response.status_code == 200:
                response.success()
            else:
                failure_msg = f"ID: {unique_id} | Status: {response.status_code}"
                response.failure(failure_msg)
~~~

