NAME := lambda-lb-target-group-dns

ifneq (,$(wildcard .env))
	include .env
  export
endif

AWK = awk
CHMOD = chmod
CURL = curl
DATE = date
DOCKER = docker
ECHO = echo
GIT = git
GO = go
GORELEASER = goreleaser
HEAD = head
INSTALL = install
MAKE = make
MKDIR = mkdir
PRINTF = printf
RM = rm
SED = sed
SORT = sort
SED = sed
TOUCH = touch

ifeq ($(OS),Darwin)
GREP = ggrep
SORT = gsort
else
GREP = grep
SORT = sort
endif

ifeq ($(GOOS),windows)
EXE = .exe
else ifeq ($(shell $(GO) env GOOS),windows)
EXE = .exe
endif

BIN = $(NAME)$(EXE)

ifeq ($(OS),Windows_NT)
ifneq (,$(LOCALAPPDATA))
BINDIR = $(LOCALAPPDATA)\Microsoft\WindowsApps
else
BINDIR = C:\Windows\System32
endif
else
ifneq (,$(wildcard $(HOME)/.local/bin))
BINDIR = $(HOME)/.local/bin
else ifneq (,$(wildcard $(HOME)/bin))
BINDIR = $(HOME)/bin
else
BINDIR = /usr/local/bin
endif
endif

VERSION = $(shell ( $(GIT) describe --tags --exact-match 2>/dev/null || ( $(GIT) describe --tags 2>/dev/null || $(ECHO) "0.0.0-0-g$$($(GIT) rev-parse --short=8 HEAD 2>/dev/null || $(ECHO) dev)" ) | $(SED) 's/-[0-9][0-9]*-g/-SNAPSHOT-/') | $(SED) 's/^v//' )
REVISION = $(shell $(GIT) rev-parse HEAD 2>/dev/null || $(ECHO) dev)
BUILDDATE = $(shell TZ=GMT $(DATE) '+%Y-%m-%dT%R:%SZ')

CGO_ENABLED = 0
export CGO_ENABLED

.PHONY: help
help:
	@echo Targets:
	@$(AWK) 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9._-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | $(SORT)

.PHONY: build
build: ## Build app binary for single target
	$(call print-target)
	$(GO) build -trimpath -ldflags="-s -w -X main.version=$(VERSION)"

.PHONY: goreleaser
goreleaser: ## Build app binary for all targets
	$(call print-target)
	$(GORELEASER) release --auto-snapshot --clean --skip-publish

$(BIN):
	@$(MAKE) build

.PHONY: install
install: ## Build and install app binary
install: $(BIN)
	$(call print-target)
	$(INSTALL) $(BIN) $(BINDIR)

.PHONY: uninstall
uninstall: ## Uninstall app binary
uninstall:
	$(RM) -f $(BINDIR)/$(BIN)

.PHONY: download
download: ## Download Go modules
	$(call print-target)
	$(GO) mod download

.PHONY: tidy
tidy: ## Tidy Go modules
	$(call print-target)
	$(GO) mod tidy

.PHONY: upgrade
upgrade: ## Upgrade Go modules
	$(call print-target)
	$(GO) get -u

.PHONY: clean
clean: ## Clean working directory
	$(call print-target)
	$(RM) -f $(BIN)
	$(RM) -rf dist

.PHONY: version
version: ## Show version
	@$(ECHO) "$(VERSION)"

.PHONY: revision
revision: ## Show revision
	@$(ECHO) "$(REVISION)"

.PHONY: builddate
builddate: ## Show build date
	@$(ECHO) "$(BUILDDATE)"

DOCKERFILE = Dockerfile
IMAGE_NAME = $(BIN)
LOCAL_REPO = localhost:5000/$(IMAGE_NAME)
DOCKER_REPO = localhost:5000/$(IMAGE_NAME)

ifeq ($(PROCESSOR_ARCHITECTURE),ARM64)
PLATFORM = linux/arm64
else ifeq ($(shell uname -m),arm64)
PLATFORM = linux/arm64
else ifeq ($(shell uname -m),aarch64)
PLATFORM = linux/arm64
else ifeq ($(findstring ARM64, $(shell uname -s)),ARM64)
PLATFORM = linux/arm64
else
PLATFORM = linux/amd64
endif

ifeq ($(PLATFORM),linux/arm64)
AWS_LAMBDA_RIE = aws-lambda-rie-arm64
AWS_LAMBDA_RIE_URL = https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie-arm64
else
AWS_LAMBDA_RIE = aws-lambda-rie-x86_64
AWS_LAMBDA_RIE_URL = https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie-x86_64
endif

.PHONY: image
image: ## Build a local image without publishing artifacts.
	$(MAKE) build GOOS=linux
	$(call print-target)
	$(DOCKER) buildx build --file=$(DOCKERFILE) \
	--platform=$(PLATFORM) \
	--build-arg VERSION=$(VERSION) \
	--build-arg REVISION=$(REVISION) \
	--build-arg BUILDDATE=$(BUILDDATE) \
	--tag $(LOCAL_REPO) \
	--load \
	.

.PHONY: push
push: ## Publish to container registry.
	$(call print-target)
	$(DOCKER) tag $(LOCAL_REPO) $(DOCKER_REPO):v$(VERSION)-$(subst /,-,$(PLATFORM))
	$(DOCKER) push $(DOCKER_REPO):v$(VERSION)-$(subst /,-,$(PLATFORM))

.aws-lambda-rie/$(AWS_LAMBDA_RIE):
	$(MKDIR) -p .aws-lambda-rie
	$(CURL) -Lo .aws-lambda-rie/$(AWS_LAMBDA_RIE) $(AWS_LAMBDA_RIE_URL)
	$(CHMOD) +x .aws-lambda-rie/$(AWS_LAMBDA_RIE)

.PHONY: test-image
test-image: .aws-lambda-rie/$(AWS_LAMBDA_RIE)
test-image: ## Test local image
	$(call print-target)
	@container=$(shell $(DOCKER) run --rm -d -v ./.aws-lambda-rie/$(AWS_LAMBDA_RIE):/aws-lambda-rie -p 8080:8080 --entrypoint /aws-lambda-rie $(LOCAL_REPO) /entrypoint); \
	$(CURL) -X POST -H "Content-Type: application/json" -d '{"name": "foo", "age": 123}' http://localhost:8080/2015-03-31/functions/function/invocations; \
	$(DOCKER) kill $$container >/dev/null

define print-target
	@$(PRINTF) "Executing target: \033[36m$@\033[0m\n"
endef
