# Interop Testing

A runbook for checking that an AAuth agent, resource or person server works against the others, for people and for AI agents running the steps for them. The servers come from the AAuth sandbox in [aauth-go](https://github.com/aauth-dev/aauth-go); its [sandbox guide](https://aauth-dev.github.io/aauth-go/guides/sandbox/) is the reference for every option used here.

## Pick What You Are Testing

| You are testing | Start the sandbox with | Then |
|-----------------|------------------------|------|
| An agent (a client of your own) | the Compose file in this repository | enroll at `https://ap.aauth.test/enroll`, call the Petstore or `https://resource.aauth.test` |
| A resource (a server of your own) | `--upstream name=http://your-server`, see [Front your own server](https://aauth-dev.github.io/aauth-go/guides/sandbox/#front-your-own-server) | run the collection or an agent against `https://name.aauth.test` |
| A person server, agent provider or access server | `--remote ps=https://your-server`, see [Test another implementation](https://aauth-dev.github.io/aauth-go/guides/sandbox/#test-another-implementation) | run the collection; the sandbox's other roles call yours |

The two reference agents are this repository's Postman collections (one request per step, so you can read each message) and [omniagent](https://github.com/plexusone/omniagent) (an AI agent that signs requests itself; see its [AAuth guide](https://plexusone.github.io/omniagent/guides/aauth/)).

## Run the Reference Setup

```bash
docker compose up -d --build --wait                          # part 1: the sandbox
docker compose --profile test run --rm newman                # 21 requests, 98 assertions
docker compose --profile petstore up -d --build --wait       # part 2: adds the Petstore
docker compose --profile petstore run --rm newman-petstore   # 10 requests, 47 assertions
```

Part 1 needs only an aauth-go checkout. Part 2 also needs a petstore checkout; skip it to test with the sandbox's own resources.

A passing run reports `0` failed. This is the baseline: if it fails, fix the setup before testing anything of your own.

Two checks that the baseline is healthy:

```bash
docker compose --profile petstore ps                                 # sandbox and petstore: healthy
docker compose exec sandbox aauth-sandbox trace --state /state | head # the message trace
```

## Test an Agent of Your Own

Inside the Compose network, the roles answer at their names, so an agent container needs no hosts entries. Run it on the same network and trust the sandbox CA from the shared `state` volume (`/state/ca.pem`):

1. Enroll at the agent provider: `POST https://ap.aauth.test/enroll` with your public key. The response is an agent token.
2. Call `https://petstore.aauth.test/v2/pet/findByStatus?status=available`, signed (RFC 9421) with `Signature-Key` carrying the agent token. Expect 200.
3. Call `POST https://petstore.aauth.test/v2/store/order`. Expect 401 with `AAuth-Requirement: requirement=person-token`, then, after you obtain a person token, 401 with `requirement=auth-token` and a resource token.
4. Send the resource token to `https://ps.aauth.test/token`. Expect 202 with a `Location` and an interaction code while the person approves, then 200 with the auth token. The sandbox approves on its own unless started with `--consent manual`.
5. Repeat the order with the auth token. Expect 200.

The trace shows each message, so compare yours with the Postman run, step by step.

## Test with an AI Agent

omniagent is a ready-made agent for this:

```bash
ANTHROPIC_API_KEY=... docker compose --profile omniagent run --rm -T omniagent \
  --prompt "Call the place-order tool now with petId 2 and quantity 1. I have already confirmed; do not ask."
```

Expect `Enrolled as aauth:assistant@ap.aauth.test`, then `Approval needed. Open …` and the order result. Notes for agents running this:

- Check pet ids first: `GET /v2/pet/findByStatus?status=available`. A sold pet is gone until the Petstore restarts; recreate the sandbox with it (`docker compose --profile petstore up -d --wait --force-recreate sandbox petstore`), see Troubleshooting.
- The model decides what to call. If it asks for confirmation or searches by a tag that matches nothing, state the tool and arguments, as above. That is the model, not AAuth.
- Judge success from the trace, not from the model's wording: the order request shows 200 and the person-server `/token` exchange shows 202 then 200.

## See a Run in the Walkthrough

`make demo` (Newman) or `make demo-omniagent` (omniagent) runs the Petstore order flow and writes `demo/live.html`, the AAuth walkthrough with the run's messages beside each step. It is the quickest way to compare your agent's messages with the protocol's: recreate the sandbox and the Petstore, run your agent against them, then turn the sandbox's trace into the page:

```bash
docker compose --profile petstore up -d --wait --force-recreate sandbox petstore
# ...run your agent...
make demo-page
```

A step marked "Not seen" is one your run did not perform; an exchange marked "Not a step in the document" is one it made that the protocol does not describe. "Weak match" means only the participants and method agreed. A match means the message looked like the step, not that it was valid.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `bind: address already in use` on 8099 or 443 | Another program uses the host port | `SIGNER_PORT=18099 SANDBOX_HTTPS_PORT=18443 docker compose up -d --wait`; containers are unaffected |
| `connection refused` to `ap.aauth.test:443` from a container | The sandbox listens on loopback only (an overriding `command` without `--listen-any-interface`) | Use this repository's `compose.yaml`, or add `--listen 0.0.0.0:443 --listen-any-interface` |
| `421 Misdirected Request` from the signing helper | The helper answers only loopback names | Add `--signer-host <service-name>` for the name your client uses |
| `x509: certificate signed by unknown authority` | The client does not trust the sandbox CA | Point it at `/state/ca.pem`, or export it with `aauth-sandbox ca export` |
| Order fails after a previous run | The pet was sold | Recreate the sandbox and the Petstore together: `docker compose --profile petstore up -d --wait --force-recreate sandbox petstore` |
| `invalid_resource_token` ("no key … in JWKS of https://petstore.aauth.test") after restarting the Petstore | The Petstore creates a new signing key at each start, and the person server keeps the key it saw | Recreate the sandbox together with the Petstore, as above |
| Old CA after rebuilding | The state volume held a CA from an older sandbox | `docker compose down -v`, then start again, and trust the new CA |

## Clean Up

```bash
docker compose down -v      # removes the containers and the sandbox's keys
```
