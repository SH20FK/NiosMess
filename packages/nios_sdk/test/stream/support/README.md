# Loopback test assets

`localhost-test-cert.pem` and `localhost-test-key.pem` are a publicly committed,
self-signed **test-only** TLS identity for `127.0.0.1` / `localhost`. They carry
no production authority or secret. Never deploy or trust this identity outside
the isolated test process. HTTPS tests explicitly add this certificate to their
own Dart isolate's trust store, then exercise normal certificate verification;
they do not install a bad-certificate callback.

The certificate is deliberately long-lived to make reproducible tests independent
of annual fixture rotation. Production endpoints use an independently managed
valid TLS certificate and never load these fixtures.
