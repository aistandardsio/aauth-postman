# Running the Collection Against the Sandbox

The signed collection drives the agent side of every AAuth access mode against real servers: the AAuth sandbox from [aauth-go](https://github.com/aauth-dev/aauth-go) runs the agent provider, resource, person server and access server in one process.

## Quick Start with Docker

```bash
docker compose up -d --wait                     # every role plus the signing helper
docker compose --profile test run --rm newman   # run the collection with Newman
docker compose down -v                          # stop and remove the sandbox's keys
```

Every sandbox option is in the [aauth-go sandbox guide](https://aauth-dev.github.io/aauth-go/guides/sandbox/); to test an implementation of your own, see the [interop runbook](interop.md).

The sandbox is built from a sibling aauth-go checkout (`AAUTH_GO_DIR`, default `../../aauth-dev/aauth-go`) until its image is published. `SIGNER_PORT` changes the helper's host port (default 8099), and `SANDBOX_HTTPS_PORT` the roles' (default 443). Both are published on `127.0.0.1` only.

The Petstore is a second part: add it with `docker compose --profile petstore up -d --build --wait` and run its collection with `docker compose --profile petstore run --rm newman-petstore`. See the [interop runbook](interop.md).

Postman needs only the helper: import the collection and the sandbox environment, set `signer_url` if you changed the port, and run. The steps below are for running the sandbox without Docker, or for talking to the roles directly from a browser.

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
aauth-sandbox init         # once: creates a local certificate authority and the keys
aauth-sandbox serve        # every role on :443, signing helper on 127.0.0.1:8099
```

Consent is approved automatically, so runs do not stop for a browser.

## 3. Trust the Sandbox CA (Direct Access Only)

Requests through the signing helper need no certificate setup. To reach the roles directly, from a browser for example, trust the sandbox's CA:

```bash
aauth-sandbox ca export > aauth-sandbox-ca.pem
# or, with Docker:
docker compose exec sandbox aauth-sandbox ca export --state /state > aauth-sandbox-ca.pem
```

In Postman: **Settings > Certificates > CA certificates**, and select `aauth-sandbox-ca.pem`.

## 4. Run

Import `collections/aauth.postman_collection.json` and `environments/sandbox.postman_environment.json`, select the environment, and run a folder. Or from the command line:

```bash
npx newman@6 run collections/aauth.postman_collection.json \
  -e environments/sandbox.postman_environment.json
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
