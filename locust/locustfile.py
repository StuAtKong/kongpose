import random
from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    wait_time = between(0.5, 1)
    host = "http://api.kong.lan"

    @task(100)
    def good_response(self):
        self.client.get("/httpbin/status/200")

    @task()
    def bad_response(self):
        self.client.get("/httpbin/status/503")

