#!/bin/bash

oc delete datasciencecluster $(oc get datasciencecluster --no-headers | awk '{print $1}')
oc delete dscinitialization $(oc get dscinitialization --no-headers | awk '{print $1}')
oc delete subscription $(oc get subscription -n redhat-ods-operator --no-headers | awk '{print $1}') -n redhat-ods-operator
oc delete operatorgroup $(oc get operatorgroup -n redhat-ods-operator --no-headers | awk '{print $1}') -n redhat-ods-operator
oc delete ns -l opendatahub.io/generated-namespace
oc delete namespace redhat-ods-operator