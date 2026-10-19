# Generate the collections and environments from PIDL's AAuth description.
# PIDL_DIR is a checkout of github.com/grokify/pidl.
PIDL_DIR ?= ../../grokify/pidl
OUT := $(CURDIR)
PIDL := cd $(PIDL_DIR) && go run ./cmd/pidl
PROTOCOL := aauth_protocol

.PHONY: generate run-sandbox

generate:
	$(PIDL) generate -f postman --signer aauth-sandbox -o $(OUT)/collections/aauth.postman_collection.json $(PROTOCOL)
	$(PIDL) generate -f postman --mock -o $(OUT)/collections/aauth-mock.postman_collection.json $(PROTOCOL)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target sandbox -o $(OUT)/environments/sandbox.postman_environment.json $(PROTOCOL)
	$(PIDL) generate -f postman-environment --targets $(OUT)/targets.json --target mock -o $(OUT)/environments/mock.postman_environment.json $(PROTOCOL)

# Run every folder against a running sandbox (aauth-sandbox serve).
run-sandbox:
	npx newman@6 run collections/aauth.postman_collection.json -e environments/sandbox.postman_environment.json
