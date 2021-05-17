import random
from datetime import datetime
import hmac, hashlib, base64

from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    wait_time = between(0.5, 1)
    host = "http://proxy.kong.lan"

    @task(100)
    def kafka_request(self):

        now = datetime.now()
        timestamp = now.strftime("%a, %d %b %Y %T.%f GMT")

        self.client.get("/dad")

