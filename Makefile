# Generate the collections and environments from the AAuth PIDL document.
# pidl runs at a released version; set PIDL to use another build, such as
# PIDL="go -C ../../grokify/pidl run ./cmd/pidl".
PIDL_VERSION ?= v0.10.0
PIDL ?= go run github.com/grokify/pidl/cmd/pidl@$(PIDL_VERSION)
OUT := $(CURDIR)

# The AAuth document comes from a release of aistandardsio/agent-protocols.
# The documents in pidl/ extend it, so it is fetched next to them.
AAUTH_PROTOCOLS_VERSION ?= v0.9.0
CURL ?= curl
AAUTH_DOC_URL := https://raw.githubusercontent.com/aistandardsio/agent-protocols/$(AAUTH_PROTOCOLS_VERSION)/aauth/pidl/aauth_protocol.json
PROTOCOL := $(CURDIR)/pidl/aauth_protocol.json
# aauth_sandbox.json and aauth_petstore.json extend it with what each set of
# resources performs.
SANDBOX := $(CURDIR)/pidl/aauth_sandbox.json
PETSTORE := $(CURDIR)/pidl/aauth_petstore.json

.PHONY: aauth-doc generate run-sandbox up up-petstore test-docker demo demo-omniagent demo-page down

# Fetch the AAuth document. Set AAUTH_DOC to use a local copy instead, such
# as an agent-protocols checkout's aauth/pidl/aauth_protocol.json.
aauth-doc:
ifdef AAUTH_DOC
	cp $(AAUTH_DOC) $(PROTOCOL)
else
	$(CURL) -fsSL -o $(PROTOCOL) $(AAUTH_DOC_URL)
endif

generate: aauth-doc
	$(PIDL) generate -f postman --signer proxy -o $(OUT)/collections/aauth.postman_collection.json $(SANDBOX)
	$(PIDL) generate -f postman --mock -o $(OUT)/collections/aauth-mock.postman_collection.json $(SANDBOX)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target sandbox -o $(OUT)/environments/sandbox.postman_environment.json $(SANDBOX)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target mock -o $(OUT)/environments/mock.postman_environment.json $(SANDBOX)
	$(PIDL) generate -f postman --signer proxy -o $(OUT)/collections/petstore.postman_collection.json $(PETSTORE)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target petstore -o $(OUT)/environments/petstore.postman_environment.json $(PETSTORE)

# Run every folder against a running sandbox (aauth-sandbox serve). Set
# SIGNER_URL when the signing helper runs on another port.
SIGNER_URL ?= http://127.0.0.1:8099

run-sandbox:
	npx newman@6 run collections/aauth.postman_collection.json -e environments/sandbox.postman_environment.json --env-var signer_url=$(SIGNER_URL)
	npx newman@6 run collections/petstore.postman_collection.json -e environments/petstore.postman_environment.json --env-var signer_url=$(SIGNER_URL)

# Part 1: start the sandbox (agent provider, person server, access server and
# its demo resources) in Docker. It needs only an aauth-go checkout.
up:
	docker compose up -d --build --wait

# Part 2: add the Petstore as a resource server behind the sandbox.
up-petstore:
	docker compose --profile petstore up -d --build --wait

# Run both collections with Newman in Docker. The Petstore creates a new
# signing key each time it starts, and the sandbox's person server keeps the
# key it saw, so the two restart together; the Petstore's pets are also
# available to order again.
test-docker: up-petstore
	docker compose --profile petstore up -d --wait --force-recreate sandbox petstore
	docker compose --profile test run --rm newman
	docker compose --profile petstore run --rm newman-petstore

# See a run beside the protocol. The demo targets run the Petstore order
# flow against fresh servers, capture the sandbox's trace of every message,
# and write demo/live.html: the AAuth walkthrough with this run's messages
# beside each step. The page opens from disk. demo/ holds the raw trace,
# real development tokens included, and is not committed.
BINDING := $(CURDIR)/bindings/sandbox-petstore.binding.json
DEMO := $(CURDIR)/demo
PROMPT ?= List the available pets, then place an order for pet 2, quantity 1. I have already confirmed; do not ask.

# Newman plays the agent, through the signing helper.
demo: up-petstore
	docker compose --profile petstore up -d --wait --force-recreate sandbox petstore
	docker compose --profile petstore run --rm newman-petstore
	$(MAKE) demo-page

# omniagent plays the agent and signs its own requests. It needs a model:
# ANTHROPIC_API_KEY, OPENAI_API_KEY or GEMINI_API_KEY in the environment.
demo-omniagent: up-petstore
	docker compose --profile petstore up -d --wait --force-recreate sandbox petstore
	docker compose --profile petstore run --rm -T omniagent --prompt "$(PROMPT)"
	$(MAKE) demo-page

demo-page: aauth-doc
	@mkdir -p $(DEMO)
	docker compose exec -T sandbox aauth-sandbox trace --state /state > $(DEMO)/trace.json
	$(PIDL) observe import --from sandbox -o $(DEMO)/run.json $(DEMO)/trace.json
	$(PIDL) generate -f viewer --observation $(DEMO)/run.json --binding $(BINDING) -o $(DEMO)/live.html $(PROTOCOL)
	@echo "Open $(DEMO)/live.html"

down:
	docker compose --profile "*" down -v
