# Openshift Serverless Logic Builder Image Test

Validates a `LOGIC_BUILDER_IMAGE` provided by the production team.

For each workflow under `workflows/`, a container image is built using the shared `Dockerfile`
and the supplied builder image. The output image is tagged as `<workflow-id>:<PRODUCT_VERSION_TAG>`
and can optionally be pushed to `quay.io/dhanak/`.

## Repository structure

```
workflows/
  callbackstatetimeouts/
    callbackstatetimeouts.sw.yaml     # no-persistence workflow
  persistentcallbackstate/
    persistentcallbackstate.sw.yaml   # persistence workflow
    .persistence                      # marker file — enables JDBC persistence extensions
Dockerfile                            # shared multi-stage build for all workflows
Makefile
```

### Adding a new workflow

1. Create `workflows/<id>/` where `<id>` matches the `id` field in the YAML file.
2. Place `<id>.sw.yaml` inside the folder.
3. If the workflow requires persistence, add an empty `.persistence` marker file.

## Required parameters

| Parameter | Description |
|---|---|
| `LOGIC_BUILDER_IMAGE` | SHA256-pinned builder image under test (e.g. `registry-proxy.../logic-swf-builder-rhel9@sha256:abc…`) |
| `PRODUCT_VERSION_TAG` | Human-readable version tag for the output image (e.g. `1.39.0`) |

## Optional parameters

| Parameter | Default | Description |
|---|---|---|
| `CONTAINER_REGISTRY` | `quay.io/dhanak` | Registry to push images to |
| `NEXUS_REPO_URL` | internal BAQE Nexus | Maven mirror for the build |
| `WORKFLOW` | *(all)* | Limit `build` / `push` to a single workflow id |

## Targets

| Target | Description |
|---|---|
| `build` | Build all workflow images locally |
| `push` | Build **and push** all workflow images to `CONTAINER_REGISTRY` |
| `build-<id>` | Build a single workflow image by id |
| `push-<id>` | Build and push a single workflow image by id |
| `help` | Print usage and list discovered workflows |

## Examples

```sh
# Build all workflows locally
make build \
  LOGIC_BUILDER_IMAGE="registry-proxy.engineering.redhat.com/rh-osbs/openshift-serverless-1-logic-swf-builder-rhel9@sha256:5fe9ca1cc84ee80f770a8d209978fe03712ecc1bf4a1ccc8c137850a468f8062" \
  PRODUCT_VERSION_TAG="1.39.0"

# Build and push all workflows
make push \
  LOGIC_BUILDER_IMAGE="registry-proxy.engineering.redhat.com/rh-osbs/openshift-serverless-1-logic-swf-builder-rhel9@sha256:5fe9ca1cc84ee80f770a8d209978fe03712ecc1bf4a1ccc8c137850a468f8062" \
  PRODUCT_VERSION_TAG="1.39.0"

# Build only the persistence workflow
make build-persistentcallbackstate \
  LOGIC_BUILDER_IMAGE="registry-proxy.engineering.redhat.com/rh-osbs/openshift-serverless-1-logic-swf-builder-rhel9@sha256:5fe9ca1cc84ee80f770a8d209978fe03712ecc1bf4a1ccc8c137850a468f8062" \
  PRODUCT_VERSION_TAG="1.39.0"

# Build a single workflow using the WORKFLOW variable
make build \
  WORKFLOW=callbackstatetimeouts \
  LOGIC_BUILDER_IMAGE="registry-proxy.engineering.redhat.com/rh-osbs/openshift-serverless-1-logic-swf-builder-rhel9@sha256:5fe9ca1cc84ee80f770a8d209978fe03712ecc1bf4a1ccc8c137850a468f8062" \
  PRODUCT_VERSION_TAG="1.39.0"

# Override the Maven mirror
make push \
  LOGIC_BUILDER_IMAGE="registry-proxy.engineering.redhat.com/rh-osbs/openshift-serverless-1-logic-swf-builder-rhel9@sha256:5fe9ca1cc84ee80f770a8d209978fe03712ecc1bf4a1ccc8c137850a468f8062" \
  PRODUCT_VERSION_TAG="1.39.0" \
  NEXUS_REPO_URL="https://repository.jboss.org/nexus/content/groups/public/"
```

## Logs

Each run produces a versioned directory under `logs/`:

```
logs/
  1.39.0/
    summary.log                        # one-glance overview of the run
    callbackstatetimeouts-build.log    # full docker build output
    persistentcallbackstate-build.log
    persistentcallbackstate-push.log   # docker push output (push target only)
    ...
  1.38.2/
    summary.log
    ...
```

**`summary.log`** contains the builder image, registry, Nexus URL, start time, and a pass/fail line per workflow — the first file to check when debugging a failed run.

```
builder : registry-proxy.../logic-swf-builder-rhel9@sha256:d5e4...
registry: quay.io/dhanak
nexus   : https://baqe-nexus.../public-pnc
started : 2026-10-12T12:00:00Z
---
build [callbackstatetimeouts] persistence=no image=quay.io/dhanak/callbackstatetimeouts:1.39.0
  result : ✅ OK
build [persistentcallbackstate] persistence=yes image=quay.io/dhanak/persistentcallbackstate:1.39.0
  result : ✅ OK
push  [callbackstatetimeouts] image=quay.io/dhanak/callbackstatetimeouts:1.39.0
  result : ✅ OK  digest=sha256:ec86...
```

Print all summaries at once:

```sh
make logs
```

Delete logs for a specific version:

```sh
make clean-logs PRODUCT_VERSION_TAG=1.39.0
```

Delete all logs:

```sh
make clean-logs
```
