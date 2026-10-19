# Running the Collection Against the Sandbox

The signed collection drives the agent side of every AAuth access mode against real servers: the AAuth sandbox from [aauth-go](https://github.com/aauth-dev/aauth-go) runs the agent provider, resource, person server and access server in one process.

## 1. Name the Servers

AAuth server identifiers are `https://` origins with a domain name and no port, so each role has its own name under the reserved `.test` domain. Add them to `/etc/hosts`:

```
127.0.0.1  ap.aauth.test ps.aauth.test as.aauth.test resource.aauth.test docs.aauth.test
```

`aauth-sandbox hosts` prints this line.

| Name | Role |
|------|------|
| `ap.aauth.test` | Agent provider |
| `ps.aauth.test` | Person server |
| `as.aauth.test` | Access server |
| `resource.aauth.test` | Resource whose tokens the person server decides |
| `docs.aauth.test` | Resource with its own access server (federated authorization) |

## 2. Start the Sandbox

```bash
aauth-sandbox ca init      # once: creates a local certificate authority
aauth-sandbox serve        # every role on :443, signing helper on 127.0.0.1:8099
```

Consent is approved automatically, so runs do not stop for a browser.

## 3. Trust the Sandbox CA

```bash
aauth-sandbox ca export > aauth-sandbox-ca.pem
```

In Postman: **Settings > Certificates > CA certificates**, and select `aauth-sandbox-ca.pem`. For Newman, pass `--ssl-extra-ca-certs aauth-sandbox-ca.pem`.

## 4. Run

Import `collections/aauth.postman_collection.json` and `environments/sandbox.postman_environment.json`, select the environment, and run a folder. Or from the command line:

```bash
npx newman@6 run collections/aauth.postman_collection.json \
  -e environments/sandbox.postman_environment.json \
  --ssl-extra-ca-certs aauth-sandbox-ca.pem
```

## How Signing Works

Postman cannot create HTTP message signatures, so every request goes to the sandbox's signing helper at `{{signer_url}}`, followed by the real target URL. Two headers tell the helper what to do, and it removes them before forwarding:

| Header | Meaning |
|--------|---------|
| `X-Sandbox-Present` | How to sign: `agent`, `person` or `auth` (present that token), `jkt-jwt` (agent provider enrollment), `hwk`, or `none` |
| `X-Sandbox-Token` | The token to present, saved from an earlier response |

The helper adds `Content-Digest` for bodies, `Signature-Key` with the presented token, and the `Signature-Input` and `Signature` headers, using the test agent's keys.

## Mock Mode

`collections/aauth-mock.postman_collection.json` carries the walkthrough's example responses as saved examples. Create a Postman mock server from it, set `mock_url` in `environments/mock.postman_environment.json`, and step through the scenarios without running anything. Mock mode signs nothing and checks only status codes.

## Regenerating

The collections and environments are generated from PIDL's AAuth description and `targets.json`:

```bash
make generate PIDL_DIR=../../grokify/pidl
```
