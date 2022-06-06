import random
from datetime import datetime
import hmac, hashlib, base64

from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    wait_time = between(0.5, 1)
    host = "http://proxy.kong.lan"

    @task(80)
    def good_response(self):
        self.client.get("/httpbin/status/200", headers={'apikey': 'keyA'})

    @task(20)
    def bad_response(self):
        self.client.get("/httpbin/status/503", headers={'apikey': 'keyA'})

    # @task(32)
    # def slow_response(self):
    #     self.client.get("/slow-httpbin/anything")

    # @task(32)
    # def hmac_auth_response(self):

    #     now = datetime.now()
    #     timestamp = now.strftime("%a, %d %b %Y %T GMT")
    #     kongConsumer = 'hmac-user'
    #     secret = bytes("K1ngK0ng", "utf-8")
    #     message = bytes("date: " + timestamp + "\nGET /auth/hmac HTTP/1.1", "utf-8")

    #     # Generate Python HMAC Signature
    #     hmacDigest = hmac.new(secret, message, hashlib.sha256).digest()
    #     hmacSig = base64.standard_b64encode(hmacDigest)

    #     hmac_headers = {
    #         'Authorization': 'hmac username="' + kongConsumer + '", algorithm="hmac-sha256", headers="date request-line", signature="' + hmacSig.decode('UTF-8') + '"',
    #         'Date': timestamp
    #         }

    #     self.client.get("/auth/hmac", headers=hmac_headers)

