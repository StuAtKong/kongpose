import random, string
from datetime import datetime
import hmac, hashlib, base64

from locust import HttpUser, task, between

def randomword(length):
   letters = string.ascii_lowercase
   return ''.join(random.choice(letters) for i in range(length))

class QuickstartUser(HttpUser):
    wait_time = between(0.5, 1)
    host = "http://proxy.kong.lan"

    @task(100)
    def rate_limit_request(self):

        now = datetime.now()
        timestamp = now.strftime("%a, %d %b %Y %T.%f GMT")

        header_value=randomword(10)
        random_header={'limit_header' : header_value}

        self.client.get("/limit-httpbin/anything?apikey=123", headers=random_header)

