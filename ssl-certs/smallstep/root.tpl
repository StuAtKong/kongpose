{
    "subject": {{ toJson .Subject }},
    "issuer": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 2
    },
    "nameConstraints": {
        "critical": true,
        "permittedDNSDomains": ["kong.lan", "kong.com"],
        "permittedIPRanges": ["127.0.0.0/8", "::1/128"]
    }
}
