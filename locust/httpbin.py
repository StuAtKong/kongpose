from locust import HttpUser, task, between, events
import random
from datetime import datetime
import hmac, hashlib, base64
from faker import Faker
import logging

#https://faker.readthedocs.io/en/master/locales/en_GB.html
fake = Faker('en_GB')

class QuickstartUser(HttpUser):
    wait_time = between(0.5, 1)
    host = "http://proxy.kong.lan"

    @task(60)
    def echo_response(self):
        self.client.get("/httpbin/anything")

    @task(40)
    def echo_response(self):

        now = datetime.now()
        timestamp = now.strftime("%a, %d %b %Y %T.%f GMT")

        payload = '{"timestamp":" '+timestamp+'", "name":"'+fake.name()+'", "address":"'+fake.address()+'"}'
        payload = payload.replace('\n',', ')
        logging.info("POST payload: " + payload)
        response = self.client.post("/httpbin/anything", payload)
