# Generate the collections and environments from PIDL's AAuth description.
# PIDL_DIR is a checkout of github.com/grokify/pidl.
PIDL_DIR ?= ../../grokify/pidl
OUT := $(CURDIR)
PIDL := cd $(PIDL_DIR) && go run ./cmd/pidl
PROTOCOL := aauth_protocol
PETSTORE := aauth_petstore

.PHONY: generate run-sandbox up test-docker down

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

# Start the sandbox in Docker, run the collection with Newman in Docker,
# and stop it again.
up:
	docker compose up -d --build --wait

test-docker: up
	docker compose --profile test run --rm newman

down:
	docker compose down -v
