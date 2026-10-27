# Generate the collections and environments from PIDL's AAuth description.
# PIDL_DIR is a checkout of github.com/grokify/pidl.
PIDL_DIR ?= ../../grokify/pidl
OUT := $(CURDIR)
PIDL := cd $(PIDL_DIR) && go run ./cmd/pidl
PROTOCOL := aauth_protocol
PETSTORE := aauth_petstore

.PHONY: generate run-sandbox up up-petstore test-docker down

generate:
	$(PIDL) generate -f postman --signer aauth-sandbox -o $(OUT)/collections/aauth.postman_collection.json $(PROTOCOL)
	$(PIDL) generate -f postman --mock -o $(OUT)/collections/aauth-mock.postman_collection.json $(PROTOCOL)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target sandbox -o $(OUT)/environments/sandbox.postman_environment.json $(PROTOCOL)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target mock -o $(OUT)/environments/mock.postman_environment.json $(PROTOCOL)
	$(PIDL) generate -f postman --signer aauth-sandbox -o $(OUT)/collections/petstore.postman_collection.json $(PETSTORE)
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

down:
	docker compose --profile "*" down -v
