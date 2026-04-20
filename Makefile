# ==========================================
# Parameters (with default fallback values)
# ==========================================
NEXUS_REPO_URL      ?= https://repository.jboss.org/nexus/content/groups/public/
CONTAINER_REGISTRY  ?= quay.io/dhanak
IMAGE_NAME          ?= logic-callbackstatetimeouts
IMAGE_TAG           ?= latest
LOGIC_BUILDER_IMAGE ?= quay.io/dhanak/logic-swf-builder:latest

# .PHONY ensures that Make doesn't confuse these targets with actual files named "all" or "build-persistence"
.PHONY: all build-persistence build-no-persistence setup-logs

# ==========================================
# Option 1: Full build (builds both)
# ==========================================
all: build-persistence build-no-persistence

# ==========================================
# Setup Logs Directory
# ==========================================
setup-logs:
	@echo "📁 Ensuring logs directory exists..."
	@mkdir -p logs

# ==========================================
# Option 2: Only persistence
# ==========================================
build-persistence: setup-logs
	@echo "🔨 Building PERSISTENCE image... (saving output to logs/persistence-build.log)"
	docker build \
		--build-arg NEXUS_REPO_URL=$(NEXUS_REPO_URL) \
		--build-arg LOGIC_BUILDER_IMAGE=$(LOGIC_BUILDER_IMAGE) \
		-t $(CONTAINER_REGISTRY)/$(IMAGE_NAME)-persistence:$(IMAGE_TAG) \
		persistence/ 2>&1 | tee logs/persistence-build.log

# ==========================================
# Option 3: Only no-persistence
# ==========================================
build-no-persistence: setup-logs
	@echo "🔨 Building NO-PERSISTENCE image... (saving output to logs/no-persistence-build.log)"
	docker build \
		--build-arg NEXUS_REPO_URL=$(NEXUS_REPO_URL) \
		--build-arg LOGIC_BUILDER_IMAGE=$(LOGIC_BUILDER_IMAGE) \
		-t $(CONTAINER_REGISTRY)/$(IMAGE_NAME)-no-persistence:$(IMAGE_TAG) \
		no-persistence/ 2>&1 | tee logs/no-persistence-build.log