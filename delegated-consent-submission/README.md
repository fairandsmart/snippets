This is an example of fairandsmart API usage with curl and jq.

The aim is to demonstrate how fairandsmart API can be used programmaticaly to push a consent *on behalf of a subject*.

Approach is based on https://fairandsmart.atlassian.net/wiki/x/JQCpmg

What this script do is:
* get an auth token,
* create a processing/preference collect transaction,
* submit user values using json,
* check recorded values are the one submitted.

For this specific case we submit the subject choices also through the API ("submit user values using json"), but you will generally let user submit their choices by using the API capacity to generate an HTML form, present it to the subject, and let the subject submit the form through regular form submission.  This can be done by pulling the HTML form instead of submitting user values using json at step 3.

Available environment variables :
* DEBUG: activate -x on bash for debug purpose if set
* SHOW_PAYLOAD: display context / transaction / values payload
* API_USER: your API login, detault is *admin*
* API_PASSWORD: your API password, detault is *password*
* API_AUTH_SERVER: your auth server, detault is *auth.fairandsmart.com*
* API_AUTH_CLIENT: your auth client, default is *cmclient*
* API_CM_SERVER: your consent-manager host, default is *johndoe-cm.fairandsmart.com*
* TX_PROCESSING: the processing ID the user will answer, default is *processing.001*
* TX_PREFERENCE: the preference ID the user will answer, default is *preference.001*
* SUBJECT_CHOICE: the answer your user will give to TX_PROCESSING, default is *accepted*
* SUBJECT_VALUE: the answer your user will give to TX_PREFERENCE, default is a random number
* TX_SUBJECT: the subject being asked, default value is *testuser@demo.com*
* TX_OBJECT: the object for which the question is asked, default value is *testing*

Before running this script, please make sure that:
* for TX_PROCESSING and TX_PREFERENCE:  exist on your environment
* for SUBJECT_CHOICE and SUBJECT_VALUE: that these values are authorized, f.e. only accepted/refused for a processing.

Env override can be done from command lie, f.e.:
`DEBUG=true TX_SUBJECT=johndoe@example.com ./consent-transaction.sh`

Expected output:
```
$ TX_SUBJECT=johndoe@example.com ./delegated-consent-submission.sh
getting auth token ... OK
creating transaction ... GvBe8pAYYg5ACoPLFtrSB7
getting task for transaction GvBe8pAYYg5ACoPLFtrSB7 ... https://johndoe-cm.fairandsmart.com/consents/GvBe8pAYYg5ACoPLFtrSB7/submit
getting form using https://johndoe-cm.fairandsmart.com/consents/GvBe8pAYYg5ACoPLFtrSB7/submit ... OK
getting processing for form ... bloc/H6szAZm/element/processing/processing.001/H6szAZm
getting preference for form ... bloc/H4DoDAV/element/preference/preference.001/H4DoDAV
posting answers accepted for bloc/H6szAZm/element/processing/processing.001/H6szAZm and 24065 for bloc/H4DoDAV/element/preference/preference.001/H4DoDAV ... OK
getting task state for transaction GvBe8pAYYg5ACoPLFtrSB7... COMMITTED
getting valid processing processing.001 value for subject johndoe@example.com ... accepted
getting valid preference preference.001 value for subject johndoe@example.com ... 24065
checking everything is OK : accepted vs accepted / 24065 vs 24065 ... OK
```