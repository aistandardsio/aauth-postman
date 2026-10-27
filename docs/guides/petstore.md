# The Petstore Demos

The [Swagger Petstore](https://github.com/grokify/petstore) runs next to the sandbox as an AAuth resource at `https://petstore.aauth.test`. Browsing needs only the agent's identity; placing an order needs the person's approval for `write:orders`. It is the second part of the setup, so the sandbox can be run and studied without it.

## Start It

With Docker, an aauth-go checkout at `../../aauth-dev/aauth-go` and a petstore checkout (v0.2.0 or later) at `../../grokify/petstore`:

```bash
docker compose --profile petstore up -d --build --wait      # the sandbox and the Petstore
docker compose --profile petstore run --rm newman-petstore  # the Petstore collection
```

Set `AAUTH_GO_DIR` or `PETSTORE_DIR` if a checkout is elsewhere.

To start over, or to make the pets available to order again, recreate the sandbox and the Petstore together:

```bash
docker compose --profile petstore up -d --wait --force-recreate sandbox petstore
```

The Petstore creates a new signing key each time it starts, and the sandbox's person server keeps the key it saw.

## Two Agents, the Same Messages

Two demos play the agent against the same servers, so they send the same messages:

| Demo | The agent | Run it |
|------|-----------|--------|
| Postman | Postman, one step per request | `collections/petstore.postman_collection.json` with `environments/petstore.postman_environment.json`, or `docker compose --profile petstore run --rm newman-petstore` |
| omniagent | [omniagent](https://github.com/plexusone/omniagent), an AI agent whose tools are the Petstore's operations | `ANTHROPIC_API_KEY=... docker compose --profile petstore run --rm omniagent` |

In the Postman folder each challenge is a request you can inspect:

1. The order is refused with `401` and `AAuth-Requirement: requirement=person-token`.
2. With a person token, it is refused again with `requirement=auth-token` and a resource token.
3. The person server asks the person to approve; the sandbox approves on its own.
4. The order goes through with the auth token.

omniagent does the same steps inside its HTTP client and prints the approval link. It needs an omniagent checkout at `../../plexusone/omniagent` (or `OMNIAGENT_DIR`) until its image is published. Compare the two in the sandbox's trace:

```bash
docker compose exec sandbox aauth-sandbox trace --state /state
```

## See Your Run Beside the Protocol

`make demo` runs the Petstore order flow against fresh servers, captures the sandbox's trace of every message, and writes `demo/live.html`: the AAuth walkthrough with this run's messages beside each step. Open it in a browser; it needs no server.

```bash
make demo             # Newman plays the agent
make demo-omniagent   # omniagent plays the agent; needs ANTHROPIC_API_KEY (or another model's key)
```

Each scenario the run performed appears as an "Observed" entry after the scenario it is an instance of. A Newman run is found as two: agent identity (browsing) and PS authorization challenged on the API call (the order). Each step shows:

- the real request and response, with when it happened and the gap from the step before;
- whether it matched the step strongly, weakly, or not at all, or could not be observed, such as the person approving in a browser;
- each token, decoded but not verified, with raw values masked;
- the exchanges the protocol does not describe, such as servers fetching each other's keys, between the steps they fell between.

A Concept / Observed switch shows the document's example instead. The run is matched to the steps by [pidl](https://grokify.github.io/pidl/guides/observed-runs/) with the binding in `bindings/sandbox-petstore.binding.json`.

The targets run pidl v0.10.0 with `go run` and fetch the AAuth document from the agent-protocols v0.9.0 release, so they need Go and network access but no checkouts of either; see [Regenerating](setup.md#regenerating) to use other versions. `demo/` holds the raw trace, with real development tokens, and is not committed.

To show a run of your own agent instead, see [See a Run in the Walkthrough](interop.md#see-a-run-in-the-walkthrough).
