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


echo -e "\n[4/4]Initializing users"
# Other commands: https://github.com/lbohnsac/quay-api#users
# Basic Guide: https://cloud.redhat.com/blog/the-quintessential-red-hat-quay-quickstart
QUAY_ROUTE=$(oc get route registry-quay -n $QUAY_PROJECT --template='https://{{ .spec.host }}')

echo -e "\n- Create the quayadmin user and retrieve the oAuth token"
QUAY_ADMIN_TOKEN=$(curl -s -X POST -k $QUAY_ROUTE/api/v1/user/initialize/ \
    -H 'Content-Type: application/json' \
    --data '{ \
    "username": "quayadmin", \
    "password":"password", \
    "email": "quayadmin@example.com", \
    "access_token": true}' | jq --raw-output .access_token)
# QUAY_ADMIN_TOKEN=Y0OM0S7MWT4NIRILGSKYUXMU1C0UOL5D2NRW72OE


echo -e "\n- Superuser details:"
echo -e "\t- Quay Route: $QUAY_ROUTE"
echo -e "\t- Quayadmin Token: $QUAY_ADMIN_TOKEN"
echo -e "\t- Username: quayadmin"
echo -e "\t- Password: password"
echo -e "\t- Podman login: podman login -u quayadmin -p password $QUAY_ROUTE"


echo -e "\n- List all current users"
curl -s -X GET $QUAY_ROUTE/api/v1/superuser/users/ \
    -H "Authorization: Bearer $QUAY_ADMIN_TOKEN" | jq .

echo -e "\n- Create organization test-org"
curl -s -X POST $QUAY_ROUTE/api/v1/organization/ \
    -H "Authorization: Bearer $QUAY_ADMIN_TOKEN" \
    -H 'Content-Type: application/json' \
    --data '{"name": "test-org", "email": "test-org@example.com"}'

echo -e "\n- Create a repo dubbed test-repo in test-org"
curl -s -X POST $QUAY_ROUTE/api/v1/repository \
    -H "Authorization: Bearer $QUAY_ADMIN_TOKEN" \
    -H 'Content-Type: application/json' \
    --data '{"namespace":"test-org", "repository":"test-repo", "visibility":"public", "description":"", "repo_kind":"image"}'

echo -e "\n- Create a user dubbed test-user"
curl -s -X POST $QUAY_ROUTE/api/v1/superuser/users/ \
    -H "Authorization: Bearer $QUAY_ADMIN_TOKEN" \
    -H 'Content-Type: application/json' \
    --data '{"username":"test-user", "email":"test-user@example.com", "access_token":true}'

echo -e "\n- Add test-user to the test-org"
curl -s -X PUT $QUAY_ROUTE/api/v1/organization/test-org/team/owners/members/test-user \
    -H "Authorization: Bearer $QUAY_ADMIN_TOKEN" \
    -H 'Content-Type: application/json' \
    --data '{}'

echo -e "\n- Add permissions to test-user to the test-repo"
curl -s -X PUT $QUAY_ROUTE/api/v1/repository/test-org/test-repo/permissions/user/test-user \
    -H "Authorization: Bearer $QUAY_ADMIN_TOKEN" \
    -H 'Content-Type: application/json' \
    --data '{"role": "admin"}'
