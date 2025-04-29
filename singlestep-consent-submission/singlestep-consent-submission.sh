#!/bin/bash

# this is an example of fairandsmart API usage with curl and jq
# loosely based on https://fairandsmart.atlassian.net/wiki/x/JQCpmg
# $TX_PREFERENCE is a "free field" preference
# $TX_PROCESSING is a processing

# strict mode
set -eEuo pipefail

# debug if wanted
DEBUG=${DEBUG:-}
[[ -n "$DEBUG" ]] && set -x

# show payloads ?
SHOW_PAYLOADS=${SHOW_PAYLOADS:-}

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
TX_CONTEXT=$(cat <<- EOM
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
}
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

[[ -n "$SHOW_PAYLOADS" ]] && (echo context payload:; echo $TX_CONTEXT | jq -r; echo)

echo -n "getting processing for form ... "
TX_PROCESSING_ACTIVE_UUID=$(curl --silent --show-error --fail \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --request GET \
    "https://$API_CM_SERVER/models/serials/$TX_PROCESSING" | jq -r .id)
TX_PROCESSING_SERIAL=$(curl -L --silent --show-error --fail \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --request GET \
    "https://$API_CM_SERVER/models/$TX_PROCESSING_ACTIVE_UUID/versions/active" | jq -r .serial)
TX_PROCESSING_ID="bloc/$TX_PROCESSING_SERIAL/element/processing/$TX_PROCESSING/$TX_PROCESSING_SERIAL"
echo "$TX_PROCESSING_ID"

echo -n "getting preference for form ... "
TX_PREFERENCE_ACTIVE_UUID=$(curl --silent --show-error --fail \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --request GET \
    "https://$API_CM_SERVER/models/serials/$TX_PREFERENCE" | jq -r .id)
TX_PREFERENCE_SERIAL=$(curl -L --silent --show-error --fail \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --request GET \
    "https://$API_CM_SERVER/models/$TX_PREFERENCE_ACTIVE_UUID/versions/active" | jq -r .serial)
TX_PREFERENCE_ID="bloc/$TX_PROCESSING_SERIAL/element/preference/$TX_PROCESSING/$TX_PROCESSING_SERIAL"
echo "$TX_PREFERENCE_ID"

FORM_VALUES='{"'$TX_PROCESSING_ID'":["'$SUBJECT_CHOICE'"], "'$TX_PREFERENCE_ID'":["'$SUBJECT_VALUE'"]}'

[[ -n "$SHOW_PAYLOADS" ]] && (echo values payload:; echo $FORM_VALUES | jq -r; echo)

TX_PAYLOAD='{"context": '$TX_CONTEXT', "values": '$FORM_VALUES'}';
[[ -n "$SHOW_PAYLOADS" ]] && (echo values payload:; echo $TX_PAYLOAD | jq -r; echo)

echo -n "single step posting of answers $SUBJECT_CHOICE for $TX_PROCESSING_ID and $SUBJECT_VALUE for $TX_PREFERENCE_ID ... "
curl --silent --show-error --fail \
    --header "Authorization: Bearer ${TOKEN}" \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --request POST \
    --data "$TX_PAYLOAD" \
    "https://$API_CM_SERVER/consents/singlestep"
echo OK
