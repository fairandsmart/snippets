This is an example of fairandsmart API usage with curl and jq.

The aim is to demonstrate how fairandsmart API can be used programmaticaly to push a consent *on behalf of a subject* in a *single transaction*.

Please report to README in delegated-consent-submission for details.

Expected output:
```
$ TX_SUBJECT=johndoe@example.com ./delegated-consent-submission.sh
getting auth token ... OK
getting task for transaction GvBe8pAYYg5ACoPLFtrSB7 ... https://johndoe-cm.fairandsmart.com/consents/GvBe8pAYYg5ACoPLFtrSB7/submit
getting form using https://johndoe-cm.fairandsmart.com/consents/GvBe8pAYYg5ACoPLFtrSB7/submit ... OK
getting processing for form ... bloc/H6szAZm/element/processing/processing.001/H6szAZm
getting preference for form ... bloc/H4DoDAV/element/preference/preference.001/H4DoDAV
posting answers accepted for bloc/H6szAZm/element/processing/processing.001/H6szAZm and 24065 for bloc/H4DoDAV/element/preference/preference.001/H4DoDAV ... OK
```