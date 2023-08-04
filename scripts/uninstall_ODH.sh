#!/bin/bash
oc delete datasciencecluster $(oc get datasciencecluster --no-headers |  awk '{print $1}')

oc delete dscinitialization $(oc get dscinitialization --no-headers |  awk '{print $1}')

oc delete subscription opendatahub-operator -n openshift-operators
oc delete ns -l opendatahub.io/generated-namespace
