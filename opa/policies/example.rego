package example

default allowBoolean = false

allowBoolean {
  header_present
}

header_present {
  input.request.http.headers["my-secret-header"] == "open-sesame"
}

allowDetailed = response {
  header_present
  response := {
    "allow": true,
    "headers": {
      "header-from-opa": "accepted",
    },
  }
}

allowDetailed = response {
  not header_present
  response := {
    "allow": false,
    "status": 418,
    "headers": {
      "header-from-opa": "rejected",
    },
  }
}

