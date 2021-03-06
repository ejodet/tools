#!/bin/bash

HOME_DIR=$(pwd)
# TODO: check what the real values should be
REGISTRY_URL="us.icr.io"
REGITRY_NAMESPACE="ibm_cloud_databases"

# TODO: REMOVE DUMMY VALUES
PIPELINE_RUN_ID="123456789"
BUILD_NUMBER="4567"

# STATIC
GIT_ROOT_URL="https://github.ibm.com/ibm-cloud-databases"

COMPONENT=$1
if [[ "$COMPONENT" == "" ]]; then
  COMPONENT="icd-orchestration"
fi

# read the source repo values.yaml
echo "Analyzing the source repository values.yaml for component $COMPONENT"
cd ibm-cloud-databases/$COMPONENT

PROJECTS=$(yq r image_values.yaml --tojson | jq 'to_entries[] | .key')

for PROJECT in $PROJECTS; do
  # project name
  PROJECT=$(echo $PROJECT | sed -e 's/^"//' -e 's/"$//')
  echo "Processing $PROJECT...."
  
  # image URL
  IMAGE_DIGEST=$(yq r image_values.yaml --tojson | jq --arg project $PROJECT '.[$project].image.digest' | sed -e 's/^"//' -e 's/"$//')
  IMAGE_NAME=$(yq r image_values.yaml --tojson | jq --arg project $PROJECT '.[$project].image.name' | sed -e 's/^"//' -e 's/"$//')
  IMAGE_URL=$REGISTRY_URL/$REGITRY_NAMESPACE/$IMAGE_NAME:$IMAGE_DIGEST
  
  # version
  VERSION=$(grep version $PROJECT/Chart.yaml | awk '{print $2};')
  
  # project URL and latest commit
  PROJECT_NAME=$PROJECT
  
  # mapping
  case $PROJECT in
    formation-autoscaler) PROJECT_NAME="operator";;
    icd-block-storage-driver | icd-block-storage-provisioner) PROJECT_NAME="armada-storage-block-plugin";;
    icd-scheduler) PROJECT_NAME="kubernetes";;
    port-scanner) PROJECT_NAME="port-scanner-image";;
    telegraf) PROJECT_NAME="telegraf-image";;
    scale-operator) PROJECT_NAME="k8s-vertical-auto-scaling";;
  esac
  REPO_URL=$GIT_ROOT_URL/$PROJECT_NAME
  COMMIT_SHA=$(git ls-remote $REPO_URL | head -1 | sed "s/HEAD//")

  # create the inventory file
  printf '{\n"artifact":"%s",\n"pipeline_run_id":"%s",\n"build_number":"%s",\n"version":"%s",\n"name":"%s",\n"repository_url":"%s",\n"commit_sha":"%s"\n}' \
  "$IMAGE_URL" "$PIPELINE_RUN_ID" "$BUILD_NUMBER" "$VERSION" "$PROJECT" "$REPO_URL" "$COMMIT_SHA" > $HOME_DIR/$PROJECT
  
  # handle sub-modules
  DEPENDENCIES=$(yq r image_values.yaml --tojson | jq --arg project $PROJECT '.[$project] | keys | map(select(. != "image")) | .[]')
  for DEPENDENCY in $DEPENDENCIES; do
    DEPENDENCY=$(echo "$DEPENDENCY" | sed -e 's/^"//' -e 's/"$//')
    echo "Processing dependency $DEPENDENCY..."
    # image URL
    IMAGE_DIGEST=$(yq r image_values.yaml --tojson | jq --arg project $PROJECT --arg dependency $DEPENDENCY '.[$project] | .[$dependency].image.digest' | sed -e 's/^"//' -e 's/"$//')
    IMAGE_NAME=$(yq r image_values.yaml --tojson | jq --arg project $PROJECT --arg dependency $DEPENDENCY '.[$project] | .[$dependency].image.name' | sed -e 's/^"//' -e 's/"$//')
    IMAGE_URL=$REGISTRY_URL/$REGITRY_NAMESPACE/$IMAGE_NAME:$IMAGE_DIGEST
    
    # version
    # TODO: none found in https://github.ibm.com/ibm-cloud-databases/ibm-cloud-databases/tree/master/icd-orchestration
    VERSION=$(grep version $IMAGE_NAME/Chart.yaml | awk '{print $2};') || true
    if [ -z "$VERSION" ]; then
      echo "Version not found - setting dummy value for now..."
      VERSION="1234"
    fi
  
    # project URL and latest commit
    PROJECT_NAME=$IMAGE_NAME
    REPO_URL=$GIT_ROOT_URL/$PROJECT_NAME
    COMMIT_SHA=$(git ls-remote $REPO_URL | head -1 | sed "s/HEAD//")

    # create the inventory file
    printf '{\n"artifact":"%s",\n"pipeline_run_id":"%s",\n"build_number":"%s",\n"version":"%s",\n"name":"%s",\n"repository_url":"%s",\n"commit_sha":"%s"\n}' \
    "$IMAGE_URL" "$PIPELINE_RUN_ID" "$BUILD_NUMBER" "$VERSION" "$PROJECT" "$REPO_URL" "$COMMIT_SHA" > $HOME_DIR/$IMAGE_NAME
  done

done
cd $HOME_DIR
echo ""
echo "Listing files..."
ls -l
echo ""
echo "Done!"