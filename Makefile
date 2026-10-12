# ==============================================================================
# Logic Builder Image Validation
# ==============================================================================
# Required parameters (no defaults — must be supplied):
#   LOGIC_BUILDER_IMAGE   SHA256-pinned builder image under test
#                         e.g. registry-proxy.../logic-swf-builder-rhel9@sha256:abc123
#   PRODUCT_VERSION_TAG   Human-readable version for the output image tag
#                         e.g. 1.39.0
#
# Optional parameters:
#   CONTAINER_REGISTRY    Target registry                (default: quay.io/dhanak)
#   NEXUS_REPO_URL        Maven mirror URL               (default: public JBoss Nexus)
#   WORKFLOW              Limit to a single workflow id  (default: all workflows)
#
# Targets:
#   build           Build image(s) locally
#   push            Build and push image(s) to CONTAINER_REGISTRY
#   build-<id>      Build a single workflow by id
#   push-<id>       Build and push a single workflow by id
#   help            Show this help
# ==============================================================================

CONTAINER_REGISTRY ?= quay.io/dhanak
NEXUS_REPO_URL     ?= https://baqe-nexus.apps.int.prod-scale-spoke1-aws-us-east-1.itup.redhat.com/nexus/content/groups/public-pnc

# Persistence extensions injected when a workflow opts in via .persistence marker
PERSISTENCE_EXTENSIONS := org.kie:kie-addons-quarkus-persistence-jdbc,io.quarkus:quarkus-jdbc-postgresql,io.quarkus:quarkus-agroal

# Discover all workflow ids from the workflows/ directory
ALL_WORKFLOWS := $(notdir $(wildcard workflows/*))

# Resolve the target workflow list: either the single WORKFLOW override or all
ifdef WORKFLOW
  TARGET_WORKFLOWS := $(WORKFLOW)
else
  TARGET_WORKFLOWS := $(ALL_WORKFLOWS)
endif

# Guard: fail early with a clear message when required parameters are missing
_check_required:
	@test -n "$(LOGIC_BUILDER_IMAGE)" || \
	  (echo "ERROR: LOGIC_BUILDER_IMAGE is required. Supply the SHA256-pinned builder image."; exit 1)
	@test -n "$(PRODUCT_VERSION_TAG)" || \
	  (echo "ERROR: PRODUCT_VERSION_TAG is required. Supply the version tag for the output image (e.g. 1.39.0)."; exit 1)

# Logs are namespaced by version: logs/<PRODUCT_VERSION_TAG>/
LOG_DIR = logs/$(PRODUCT_VERSION_TAG)

setup-logs:
	@mkdir -p $(LOG_DIR)
	@echo "builder : $(LOGIC_BUILDER_IMAGE)" >  $(LOG_DIR)/summary.log
	@echo "registry: $(CONTAINER_REGISTRY)"  >> $(LOG_DIR)/summary.log
	@echo "nexus   : $(NEXUS_REPO_URL)"       >> $(LOG_DIR)/summary.log
	@echo "started : $$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> $(LOG_DIR)/summary.log
	@echo "---"                               >> $(LOG_DIR)/summary.log

# ------------------------------------------------------------------------------
# Internal macro: build one workflow image
# Usage: $(call build-workflow,<id>)
# ------------------------------------------------------------------------------
define build-workflow
	$(eval WF_ID    := $(1))
	$(eval WF_DIR   := workflows/$(WF_ID))
	$(eval WF_IMAGE := $(CONTAINER_REGISTRY)/$(WF_ID):$(PRODUCT_VERSION_TAG))
	$(eval WF_LOG   := $(LOG_DIR)/$(WF_ID)-build.log)
	$(eval WF_EXTS  := $(if $(wildcard $(WF_DIR)/.persistence),$(PERSISTENCE_EXTENSIONS),))
	@echo ""
	@echo "🔨 Building [$(WF_ID)] → $(WF_IMAGE)"
	@echo "   persistence : $(if $(wildcard $(WF_DIR)/.persistence),yes,no)"
	@echo "   log         : $(WF_LOG)"
	@echo "build [$(WF_ID)] persistence=$(if $(wildcard $(WF_DIR)/.persistence),yes,no) image=$(WF_IMAGE)" >> $(LOG_DIR)/summary.log
	@{ \
	  docker build \
	    --build-arg LOGIC_BUILDER_IMAGE="$(LOGIC_BUILDER_IMAGE)" \
	    --build-arg NEXUS_REPO_URL="$(NEXUS_REPO_URL)" \
	    $(if $(WF_EXTS),--build-arg QUARKUS_EXTENSIONS="$(WF_EXTS)",) \
	    -t $(WF_IMAGE) \
	    -f Dockerfile \
	    $(WF_DIR)/ 2>&1 | tee $(WF_LOG); \
	  RC=$${PIPESTATUS[0]}; \
	  if [ $$RC -eq 0 ]; then \
	    echo "  result : ✅ OK" >> $(LOG_DIR)/summary.log; \
	    echo "✅ $(WF_ID) built successfully"; \
	  else \
	    echo "  result : ❌ FAILED (exit $$RC)" >> $(LOG_DIR)/summary.log; \
	    echo "❌ $(WF_ID) build FAILED — see $(WF_LOG)"; \
	    exit $$RC; \
	  fi; \
	}
endef

# ------------------------------------------------------------------------------
# Internal macro: push one workflow image (must be built first)
# Usage: $(call push-workflow,<id>)
# ------------------------------------------------------------------------------
define push-workflow
	$(eval WF_ID    := $(1))
	$(eval WF_IMAGE := $(CONTAINER_REGISTRY)/$(WF_ID):$(PRODUCT_VERSION_TAG))
	$(eval WF_LOG   := $(LOG_DIR)/$(WF_ID)-push.log)
	@echo ""
	@echo "🚀 Pushing [$(WF_ID)] → $(WF_IMAGE)"
	@echo "push  [$(WF_ID)] image=$(WF_IMAGE)" >> $(LOG_DIR)/summary.log
	@{ \
	  docker push $(WF_IMAGE) 2>&1 | tee $(WF_LOG); \
	  RC=$${PIPESTATUS[0]}; \
	  if [ $$RC -eq 0 ]; then \
	    DIGEST=$$(grep "digest:" $(WF_LOG) | awk '{print $$3}'); \
	    echo "  result : ✅ OK  digest=$$DIGEST" >> $(LOG_DIR)/summary.log; \
	    echo "✅ $(WF_ID) pushed successfully"; \
	  else \
	    echo "  result : ❌ FAILED (exit $$RC)" >> $(LOG_DIR)/summary.log; \
	    echo "❌ $(WF_ID) push FAILED — see $(WF_LOG)"; \
	    exit $$RC; \
	  fi; \
	}
endef

# ------------------------------------------------------------------------------
# Public targets
# ------------------------------------------------------------------------------
.PHONY: build push logs clean-logs help setup-logs _check_required \
        $(addprefix build-,$(ALL_WORKFLOWS)) \
        $(addprefix push-,$(ALL_WORKFLOWS))

## Build image(s) locally. Use WORKFLOW=<id> to target a single workflow.
build: _check_required setup-logs
	$(foreach wf,$(TARGET_WORKFLOWS),$(call build-workflow,$(wf)))

## Build and push image(s) to CONTAINER_REGISTRY. Use WORKFLOW=<id> to target a single workflow.
push: _check_required setup-logs
	$(foreach wf,$(TARGET_WORKFLOWS),$(call build-workflow,$(wf)))
	$(foreach wf,$(TARGET_WORKFLOWS),$(call push-workflow,$(wf)))

# Per-workflow convenience targets (auto-generated for each discovered workflow)
$(addprefix build-,$(ALL_WORKFLOWS)): build-%: _check_required setup-logs
	$(call build-workflow,$*)

$(addprefix push-,$(ALL_WORKFLOWS)): push-%: _check_required setup-logs
	$(call build-workflow,$*)
	$(call push-workflow,$*)

## Show a summary of all logged runs (contents of each logs/<version>/summary.log)
logs:
	@for f in logs/*/summary.log; do \
	  echo ""; \
	  echo "════════════════════════════════════════"; \
	  echo "  $$f"; \
	  echo "════════════════════════════════════════"; \
	  cat "$$f"; \
	done
	@echo ""

## Delete logs for a specific version: make clean-logs PRODUCT_VERSION_TAG=1.39.0
## Omit PRODUCT_VERSION_TAG to delete ALL logs.
clean-logs:
ifdef PRODUCT_VERSION_TAG
	@echo "🗑️  Removing logs/$(PRODUCT_VERSION_TAG)/"
	@rm -rf logs/$(PRODUCT_VERSION_TAG)
else
	@echo "🗑️  Removing all logs/"
	@rm -rf logs/
endif

## Show this help message
help:
	@echo ""
	@echo "Usage: make <target> LOGIC_BUILDER_IMAGE=<image> PRODUCT_VERSION_TAG=<version> [OPTIONS]"
	@echo ""
	@echo "Targets:"
	@echo "  build                Build all workflow images locally"
	@echo "  push                 Build and push all workflow images to CONTAINER_REGISTRY"
	@echo "  build-<id>           Build a single workflow image  (e.g. make build-callbackstatetimeouts)"
	@echo "  push-<id>            Build and push a single image  (e.g. make push-persistentcallbackstate)"
	@echo "  logs                 Print summary of all logged runs"
	@echo "  clean-logs           Delete logs for PRODUCT_VERSION_TAG (or all if unset)"
	@echo ""
	@echo "Options:"
	@echo "  LOGIC_BUILDER_IMAGE  [REQUIRED] SHA256-pinned builder image under test"
	@echo "  PRODUCT_VERSION_TAG  [REQUIRED] Version tag for output images (e.g. 1.39.0)"
	@echo "  WORKFLOW             Limit build/push to a single workflow id"
	@echo "  CONTAINER_REGISTRY   Target registry (default: $(CONTAINER_REGISTRY))"
	@echo "  NEXUS_REPO_URL       Maven mirror   (default: $(NEXUS_REPO_URL))"
	@echo ""
	@echo "Discovered workflows: $(ALL_WORKFLOWS)"
	@echo ""
