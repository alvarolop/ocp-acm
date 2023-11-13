#!/bin/sh

set -e

# Set your environment variables here
QUAY_PROJECT=quay-enterprise
QUAY_S3_BUCKET=quay-s3-bucket

#############################
## Do not modify anything from this line
#############################

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * QUAY_PROJECT: $QUAY_PROJECT"
echo -e " * QUAY_S3_BUCKET: $QUAY_S3_BUCKET"

echo -e "==============\n"

# Check if the user is logged in 
if ! oc whoami &> /dev/null; then
    echo -e "Check. You are not logged. Please log in and run the script again."
    exit 1
else
    echo -e "Check. You are correctly logged in. Continue..."
    if ! oc project &> /dev/null; then
        echo -e "Current project does not exist, moving to project Default."
        oc project default 
    fi
fi


# Install the operator
echo -e "\n[1/4]Deploying the Quay operator"
oc apply -f openshift/quay/00-subscription.yaml

echo -n "Waiting for operator pods to be ready..."
while [[ $(oc get pods -l "name=quay-operator-alm-owned" -n openshift-operators -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"


echo -e "\n[2/4]Create an AWS S3 Bucket"
# Create an AWS S3 Bucket to store the images
./aws-create-bucket.sh $QUAY_S3_BUCKET ./aws-env-vars


echo -e "\n[3/4]Deploying the Quay instance"
# 3. Create Thanos S3 secret and observability components
oc process -f openshift/quay/10-quayregistry.yaml \
    --param-file ./aws-env-vars --ignore-unknown-parameters=true \
    -p AWS_S3_BUCKET=$QUAY_S3_BUCKET \
    -p QUAY_PROJECT=$QUAY_PROJECT | oc apply -f -
