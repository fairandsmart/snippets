#!/bin/bash

# this is an example of fairandsmart API usage with curl and jq
# loosely based on https://fairandsmart.atlassian.net/wiki/x/JQCpmg
# $TX_PREFERENCE is a "free field" preference
# $TX_PROCESSING is a processing

# strict mode
set -eEuo pipefail

# debug if wanted
[[ -n "$DEBUG" ]] && set -x

# error handler
trap 'echo FAIL: got error code $? on line $BASH_LINENO, cmd : $BASH_COMMAND ' ERR

# auth and credentials
API_USER=${API_USER:-admin}
API_PASSWORD=${API_PASSWORD:-password}
API_AUTH_SERVER=${API_AUTH_SERVER:-auth.fairandsmart.com}
API_AUTH_CLIENT=${API_AUTH_CLIENT:-cmclient}
# backend
API_CM_SERVER=${API_CM_SERVER:-johndoe-cm.fairandsmart.com}
# subject questions; please make sure they exist on your environment
TX_PROCESSING=${TX_PROCESSING:-processing.001}
TX_PREFERENCE=${TX_PREFERENCE:-preference.001}
# subject answers; please make sure these values are authorized, f.e. only accepted/refused for a processing
SUBJECT_CHOICE=${SUBJECT_CHOICE:-accepted}
SUBJECT_VALUE=${SUBJECT_VALUE:-$RANDOM}
# transaction context; for layoutData, see head to Collection // Quick Editor
TX_SUBJECT=${TX_SUBJECT:-testuser@demo.com}
TX_OBJECT=${TX_OBJECT:-testing}
TX_PAYLOAD=$(cat <<- EOM
{
    "subject": "$TX_SUBJECT",
    "origin": "OPERATOR",
    "object": "$TX_OBJECT",
    "layoutData":{
        "type": "layout",
        "info": "",
        "blocs": [
            {
                "parent": {
                    "key": "$TX_PROCESSING"
                },
                "children": []
            },
            {
                "parent": {
                    "key": "$TX_PREFERENCE"
                },
                "children": []
            }
        ],
        "defaultNotification": "",
        "orientation": "VERTICAL",
        "acceptAllText": "",
        "acceptAllVisible": false,
        "submitText": "",
        "cancelVisible": false,
        "cancelText": "",
        "footerOnTop": false
    }
}'
EOM
)

# sanity checks
which curl > /dev/null
which jq > /dev/null

echo -n "getting auth token ... "
TOKEN=$(curl --silent --show-error --fail \
    --data-urlencode "client_id=$API_AUTH_CLIENT" \
    --data-urlencode "username=$API_USER" \
    --data-urlencode "password=$API_PASSWORD" \
    --data-urlencode "grant_type=password" \
    "https://$API_AUTH_SERVER/auth/realms/FairAndSmart/protocol/openid-connect/token" \
    | jq -r '.access_token')
echo OK

echo -n "creating transaction ... "
RES=$(curl --silent --show-error --fail \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --request POST \
    --data "$TX_PAYLOAD" \
    "https://$API_CM_SERVER/consents")
TX_ID=$(echo $RES | jq -r .id)
TX_TOKEN=$(echo $RES | jq -r .token)
echo "$TX_ID"

echo -n "getting task for transaction $TX_ID ... "
TX_TASK=$(curl --silent --show-error --fail \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Accept: application/json" \
    https://$API_CM_SERVER/consents/${TX_ID} \
    | jq -r .task)
echo "$TX_TASK"

echo -n "getting form using $TX_TASK ... "
TX_FORM=$(curl --silent --show-error --fail \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Accept: application/json" \
    "$TX_TASK?t=$TX_TOKEN")
echo OK

echo -n "getting processing for form ... "
TX_PROCESSING_ID=$(echo "$TX_FORM" | jq -r '.blocs[] | select (.parent.element.entry.key | contains("'$TX_PROCESSING'") ) .parent.identifier')
echo "$TX_PROCESSING_ID"

echo -n "getting preference for form ... "
TX_PREFERENCE_ID=$(echo "$TX_FORM" | jq -r '.blocs[] | select (.parent.element.entry.key | contains("'$TX_PREFERENCE'") ) .parent.identifier')
echo "$TX_PREFERENCE_ID"

FORM_VALUES='{"'$TX_PROCESSING_ID'":["'$SUBJECT_CHOICE'"], "'$TX_PREFERENCE_ID'":["'$SUBJECT_VALUE'"]}'
echo -n "posting answers $SUBJECT_CHOICE for $TX_PROCESSING_ID and $SUBJECT_VALUE for $TX_PREFERENCE_ID ... "
curl --silent --show-error --fail \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --request POST \
    --data "$FORM_VALUES" \
    "$TX_TASK?t=$TX_TOKEN"
echo OK

echo -n "getting task state for transaction $TX_ID... "
TX_STATE=$(curl --silent --show-error --fail \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Accept: application/json" \
    https://$API_CM_SERVER/consents/${TX_ID} \
    | jq -r .state)
echo "$TX_STATE"

echo -n "getting valid processing $TX_PROCESSING value for subject $TX_SUBJECT ... "
RECEIVED_CHOICE=$(curl --silent --show-error --fail \
    --header "Authorization: Bearer $TOKEN" \
    "https://$API_CM_SERVER/records?subject=$TX_SUBJECT&elements=$TX_PROCESSING&object=$TX_OBJECT" \
    | jq -r '."'$TX_PROCESSING'|'$TX_SUBJECT'|'$TX_OBJECT'"[] | select( .status | contains("VALID")) .value')
echo "$RECEIVED_CHOICE"

echo -n "getting valid preference $TX_PREFERENCE value for subject $TX_SUBJECT ... "
RECEIVED_VALUE=$(curl --silent --show-error --fail \
    --header "Authorization: Bearer $TOKEN" \
    "https://$API_CM_SERVER/records?subject=$TX_SUBJECT&elements=$TX_PREFERENCE&object=$TX_OBJECT" \
    | jq -r '."'$TX_PREFERENCE'|'$TX_SUBJECT'|'$TX_OBJECT'"[] | select( .status | contains("VALID")) .value')
echo "$RECEIVED_VALUE"

echo -n "checking everything is OK : $SUBJECT_CHOICE vs $RECEIVED_CHOICE / $SUBJECT_VALUE vs $RECEIVED_VALUE ... "
if [[ "$SUBJECT_CHOICE" == "$RECEIVED_CHOICE" ]] && [[ "$SUBJECT_VALUE" == "$RECEIVED_VALUE" ]]; then
    echo OK
    exit 0
else
    echo KO
    exit 1
fi
