# Openshift Serverless Logic Builder Image Test
A repository with tests for Logic Builder image.

Contains `Dockerfile`'s that prove the Logic Builder image is working as expected.

We are using `Makefile` to orchestrate the build options.
Please check the file for further details.

# How to run the test

## Supported parameters
```console
# Use to override the default maven repositories, useful when using proxy or other non-public repositories
NEXUS_REPO_URL      ?= https://repository.jboss.org/nexus/content/groups/public/
# Registry of the resulting image
CONTAINER_REGISTRY  ?= quay.io/dhanak
# Name base of the resulting images
IMAGE_NAME          ?= logic-callbackstatetimeouts
# Tag of the resulting images
IMAGE_TAG           ?= latest
# What builder images to use for build the workflow applications
LOGIC_BUILDER_IMAGE ?= quay.io/dhanak/logic-swf-builder:latest
```

## Example command to execute build of all images with specific parameters
```console
make all \
  NEXUS_REPO_URL="https://repository.jboss.org/nexus/content/groups/public/" \
  CONTAINER_REGISTRY="quay.io/dhanak" \
  IMAGE_NAME="logic-callbackstatetimeouts" \
  IMAGE_TAG="1.0.0" \
  LOGIC_BUILDER_IMAGE="quay.io/dhanak/"
```