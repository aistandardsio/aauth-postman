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

Postman cannot create HTTP message signatures, so every signed request goes to the sandbox's signing helper at `{{signer_url}}`, followed by the real target URL. The request's `Signature-Key` header tells the helper how to sign:

| `Signature-Key` | Meaning |
|-----------------|---------|
| `sig=jwt;jwt="{{agent_token}}"` | Present that token, saved from an earlier response, as the agent, person or auth token its `typ` names |
| `sig=jwt` | Present the helper's own agent token |
| `sig=jkt-jwt` | Agent provider enrollment |
| `sig=hwk` | Sign with the header web key scheme |

The helper replaces it with the real `Signature-Key`, and adds `Content-Digest` for bodies and the `Signature-Input` and `Signature` headers, using the test agent's keys. Requests that carry no signature are sent directly.

## Mock Mode

`collections/aauth-mock.postman_collection.json` carries the walkthrough's example responses as saved examples. Create a Postman mock server from it, set `mock_url` in `environments/mock.postman_environment.json`, and step through the scenarios without running anything. Mock mode signs nothing and checks only status codes.

## Regenerating

The collections and environments are generated with [pidl](https://github.com/grokify/pidl) from the documents in `pidl/` and `targets.json`:

```bash
make generate
```

| Document | Collections | Scenarios |
|----------|-------------|-----------|
| `pidl/aauth_sandbox.json` | `aauth`, `aauth-mock` | The five access modes, as the sandbox's resources perform them |
| `pidl/aauth_petstore.json` | `petstore` | Browsing the pets and placing an order |

Both extend the AAuth document, `aauth/pidl/aauth_protocol.json` in [agent-protocols](https://github.com/aistandardsio/agent-protocols), which `make` fetches from a release into `pidl/aauth_protocol.json`. The sandbox document leaves out the variant in which the resource challenges on the API call, because the sandbox's resources publish an authorization endpoint instead; the Petstore's order flow performs it.

| Variable | Default | Sets |
|----------|---------|------|
| `PIDL_VERSION` | `v0.10.0` | The pidl release that `go run` uses |
| `PIDL` | `go run github.com/grokify/pidl/cmd/pidl@$(PIDL_VERSION)` | The pidl command, such as `PIDL="go -C ../../grokify/pidl run ./cmd/pidl"` for a checkout |
| `AAUTH_PROTOCOLS_VERSION` | `v0.9.0` | The agent-protocols release the AAuth document comes from |
| `AAUTH_DOC` | | A local AAuth document to use instead, such as an agent-protocols checkout's |
| `CURL` | `curl` | The curl command that fetches it |
