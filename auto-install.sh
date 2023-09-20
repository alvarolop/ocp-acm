#!/bin/sh

set -e

# Set your environment variables here
ACM_NAMESPACE=open-cluster-management

#############################
## Do not modify anything from this line
#############################

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * ACM_NAMESPACE: $ACM_NAMESPACE"
echo -e "==============\n"

# Check if the user is logged in 
if ! oc whoami &> /dev/null; then
    echo -e "Check. You are not logged out. Please log in and run the script again."
    exit 1
else
    echo -e "Check. You are correctly logged in. Continue..."
    if ! oc project &> /dev/null; then
        echo -e "Current project does not exist, moving to project Default."
        oc project default 
    fi
fi

# 1) Deploy the ACM operator
echo -e "\n[1/3]Deploying the ACM operator"
oc process -f openshift/00-operator.yaml \
    -p ACM_NAMESPACE=$ACM_NAMESPACE | oc apply -f -

echo ""
echo -n "Waiting for multiclusterhub pods ready..."
while [[ $(oc get pods -l name=multiclusterhub-operator -n $ACM_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"
echo -n "Waiting for multicluster-observability pods ready..."
while [[ $(oc get pods -l name=multicluster-observability-operator -n $ACM_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"
echo -n "Waiting for submariner-addon pods ready..."
while [[ $(oc get pods -l app=submariner-addon -n $ACM_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"


# 2) Deploy the ACM cluster
echo -e "\n[2/3]Deploying the ACM cluster"
oc process -f openshift/10-multi-cluster-hub.yaml \
    -p ACM_NAMESPACE=$ACM_NAMESPACE | oc apply -f -

echo -n "Waiting for ACM cluster to be running (Currently: $(oc get multiclusterhub -n $ACM_NAMESPACE -o=jsonpath='{.items[0].status.phase}'))..."
# oc wait --for=condition=running multiclusterhub multiclusterhub -n $ACM_NAMESPACE
while [[ $(oc get multiclusterhub -n $ACM_NAMESPACE -o=jsonpath='{.items[0].status.phase}') != "Running" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"
