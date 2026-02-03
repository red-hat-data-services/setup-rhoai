#!/usr/bin/env bash

set -euo pipefail

# BASE_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]} ))

# source "${BASE_DIR}/utils/gitops.sh"

OPENSHIFT_MARKETPLACE_NAMESPACE="openshift-marketplace"
# RHOAI specific namespaces
RHODS_OPERATOR_NAMESPACE="redhat-ods-operator"
RHODS_APPS_NAMESPACE="redhat-ods-applications"
RHODS_AUTH_PROVIDER_NAMESPACE="redhat-ods-applications-auth-provider"
RHODS_MONITORING_NAMESPACE="redhat-ods-monitoring"
RHODS_NOTEBOOKS_NAMESPACE="rhods-notebooks"
RHODS_MODEL_REGISTRY_NAMESPACE="rhoai-model-registries"
# OpenDataHub specific namespaces
OPENDATAHUB_NAMESPACE="opendatahub"
OPENDATAHUB_OPERATOR_SYSTEM_NAMESPACE="opendatahub-operator-system"
OPENDATAHUB_OPERATORS_NAMESPACE="opendatahub-operators"  # This seems to be used just in our ods-ci automation, not the product thing; but still, we shall remove it then.
OPENDATAHUB_AUTH_PROVIDER_NAMESPACE="opendatahub-auth-provider"
OPENDATAHUB_MODEL_REGISTRY_NAMESPACE="odh-model-registries"
# Custom namespaces
CUSTOM_OPERATOR_NAMESPACE="custom-ns-operator"
CUSTOM_APPS_NAMESPACE="custom-ns-apps"
CUSTOM_WB_NAMESPACE="custom-ns-wbs"

GRACEFUL_UNINSTALL="false"
KEEP_CRDS="false"
KEEP_USER_RESOURCES="false"
ADDITIONAL_OPERATORS=""
ALL_OPERATORS="authorino serverless servicemesh clusterobservability tempo opentelemetry kueue cma certmanager connectivitylink leaderworkerset jobset"

GITOPS_CLI_REPO_URL=""
GITOPS_CLI_REPO_BRANCH=""
LOCAL_GITOPS_CLI_REPO="false"

# Read script arguments from the CLI
function usage() {
  cat << EOF >&2
This script serves to uninstall RHOAI from your OpenShift cluster removing all
the expected resources leaving the cluster free for another installation of RHOAI.

Usage: $0 -t <operator|addon|gitops-cli-dependencies> [-g] [-k] [-K] [-r] [-b] [-l]

  -t <operator|addon>    The type of the installation used for RHOAI when installed.

  -g                     Optional, disabled by default.
                         When set, the RHOAI is removed gracefully before the force uninstall.
                         This will give RHOAI a chance to remove all resources in the expected order and running e.g. resource finalizers properly.
                         Please note that this option will work only if the RHOAI is installed on the cluster in some decend state so that it is
                         able to follow the gracefull uninstallation method. Otherwise it won't work anyway.

                         This works only for the "operator" installation type at the moment, and it is ignored for the "addon" installation type.

  -k                     Optional, disabled by default.
                         When set, the CRDs related to RHOAI will be kept in the cluster.

  -K                     Optional, disabled by default.
                         When set, the user resources (data science projects, CRs, ...) and CRDs related to RHOAI will be kept in the cluster.

  -a                     Optional, empty by default.
                         Specify additional operators (or subset) to be uninstalled.
                         For example -a 'authorino serverless servicemesh clusterobservability tempo opentelemetry kueue cma'

  -r                     Optional, 'https://github.com/davidebianchi/rhoai-gitops.git' by default.
                         Specify the URL of the GitOps CLI repository.

  -b                     Optional, 'main' by default.
                         Specify the branch of the GitOps CLI repository.

  -l                     Optional, disabled by default.
                         When set, use local GitOps CLI repository without updating from remote.

EOF
  exit 1
}

while getopts ":t:gkKa:r:b:l" o; do
  case "${o}" in
    t)
      INSTALLATION_TYPE=${OPTARG}
      if [[ ! ${INSTALLATION_TYPE} =~ ^(operator|addon|gitops-cli-dependencies)$ ]]; then
        usage
      fi
      ;;
    g)
      GRACEFUL_UNINSTALL="true"
      ;;
    k)
      KEEP_CRDS="true"
      ;;
    K)
      KEEP_CRDS="true"
      KEEP_USER_RESOURCES="true"
      ;;
    a)
      ADDITIONAL_OPERATORS=${OPTARG}
      ;;
    r)
      GITOPS_CLI_REPO_URL=${OPTARG}
      ;;
    b)
      GITOPS_CLI_REPO_BRANCH=${OPTARG}
      ;;
    l)
      LOCAL_GITOPS_CLI_REPO="true"
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z "${INSTALLATION_TYPE-}" ]; then
  usage
fi

#if [ -z "${GITOPS_CLI_REPO_URL}" ]; then
#  GITOPS_CLI_REPO_URL="${DEFAULT_GITOPS_CLI_REPO_URL}"
#fi

#if [ -z "${GITOPS_CLI_REPO_BRANCH}" ]; then
#  GITOPS_CLI_REPO_BRANCH="${DEFAULT_GITOPS_CLI_REPO_BRANCH}"
#fi


if [ ${GRACEFUL_UNINSTALL} = "true" ]; then
    # Graceful uninstall
    if [ ${INSTALLATION_TYPE} == "operator" ]; then
        # https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2-latest/html-single/installing_and_uninstalling_openshift_ai_self-managed/index#uninstalling-openshift-ai-self-managed_uninstalling-openshift-ai-self-managed
        echo "Removing RHODS gracefully first. Please be patient..."
        echo "Creating the 'delete-self-managed-odh' configmap"
        oc create configmap delete-self-managed-odh -n ${RHODS_OPERATOR_NAMESPACE}
        oc label configmap/delete-self-managed-odh api.openshift.com/addon-managed-odh-delete=true -n ${RHODS_OPERATOR_NAMESPACE}

        echo "Waiting for the '$RHODS_APPS_NAMESPACE' project to be removed"
        if oc wait --for=delete --timeout=300s project "${RHODS_APPS_NAMESPACE}"; then
            echo "The '$RHODS_APPS_NAMESPACE' project no longer exists"
        else
            echo "Warning: The '$RHODS_APPS_NAMESPACE' project wasn't removed after 5 minutes. There is probably something wrong with the gracefull uninstall!"
        fi

        echo "Let's remove the 'delete-self-managed-odh' ConfigMap and ${RHODS_OPERATOR_NAMESPACE} namespace"
        oc delete configmap delete-self-managed-odh -n ${RHODS_OPERATOR_NAMESPACE}
        oc delete --wait=true --timeout=60s namespace ${RHODS_OPERATOR_NAMESPACE} --ignore-not-found
    else
        echo "The gracefull uninstallation is not supported for the 'addon' installation type at the moment, ignoring this option for now."
    fi
fi

function delete_finalizers (){
	echo "Deleting finalizers for all instances of $1 ..."
  oc get "$1" --all-namespaces -o custom-columns=:metadata.name --ignore-not-found --no-headers=true | xargs -I {} oc patch "$1" {} --type=merge -p '{"metadata": {"finalizers":null}}' || true
}

function delete_webhooks(){
  local name="${1}"
  local webhooks

  # Delete Validating Webhooks
  echo "Deleting validatingwebhookconfigurations for ${name}"
  webhooks=$(oc get validatingwebhookconfiguration -o json | jq -r --arg name "${name}" '.items[] | select(.metadata.name | test($name)) | .metadata.name')
  for webhook in ${webhooks}; do
    oc delete validatingwebhookconfiguration "${webhook}"
  done
  if [[ -z "${webhooks}" ]]; then
    echo "No webhooks found"
  fi
  # Delete Mutating Webhooks
  echo "Deleting mutatingwebhookconfigurations for ${name}"
  webhooks=$(oc get mutatingwebhookconfiguration -o json | jq -r --arg name "${name}" '.items[] | select(.metadata.name | test($name)) | .metadata.name')
  for webhook in ${webhooks}; do
    oc delete mutatingwebhookconfiguration "${webhook}"
  done
  if [[ -z "${webhooks}" ]]; then
    echo "No webhooks found"
  fi
}

function delete_resources (){
  echo "Deleting all ${1} resources"
  # Check if the api-resource exists
  local crd=$(oc get crd "${1}" --no-headers --ignore-not-found)
  local api_resource=$(oc api-resources --no-headers | awk '{ print $1, $NF}' | grep -iw "${1}")
  if [ -n "${crd}${api_resource}" ]; then
    # Delete resources removing the finalizers and then remove it in a standard way and wait for 10m
    delete_finalizers_using_namespace "${1}"
    oc delete "${1}" --all -A --ignore-not-found --timeout=600s
  else
    echo "The server doesn't have a resource type ${1}"
  fi
}

function delete_finalizers_using_namespace (){
	echo "Deleting finalizers for all instances of $1 ..."
  oc get "$1" --all-namespaces -o custom-columns=:kind,:metadata.name,:metadata.namespace --ignore-not-found --no-headers=true | xargs -n 3 sh -c 'resource=$1;name=$2; namespace=$3; oc patch $resource $name --type=merge -p "{\"metadata\": {\"finalizers\":null}}" --namespace $namespace' sh || true
}

function cleanup_stale_apiservices() {
  echo "Checking for stale APIServices that block discovery..."
  # Find all APIServices where Available is not True
  local stale_apis=$(oc get apiservice -o json | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Available" and .status!="True")) | .metadata.name')

  if [[ -n "${stale_apis}" ]]; then
    for api in ${stale_apis}; do
      echo "  Detected stale APIService: ${api}. Deleting to unblock discovery..."
      oc delete apiservice "${api}" --timeout=15s --ignore-not-found || true
    done
  else
    echo "  No stale APIServices detected."
  fi
}

function delete_resource_with_timeout() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="$3"
  local timeout="${4:-10s}"
  echo "Attempting to delete ${resource_type} ${resource_name} in namespace ${namespace} with timeout ${timeout}..."
  if oc delete "${resource_type}" "${resource_name}" -n "${namespace}" --timeout="${timeout}" --ignore-not-found 2>&1 | grep -q "timed out"; then
    echo "Deletion timed out, removing finalizers and retrying..."
    oc patch "${resource_type}" "${resource_name}" -n "${namespace}" --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null || true
    oc delete "${resource_type}" "${resource_name}" -n "${namespace}" --ignore-not-found
  fi
}

function delete_namespace_with_cleanup() {
  local namespaces="$@"

  for ns in ${namespaces}; do
    echo "Processing namespace: $ns"

    # Delete all resources in the namespace with a timeout
    if oc get ns $ns &>/dev/null; then
      echo "  Deleting resources in namespace $ns..."
      oc delete all --all -n $ns --ignore-not-found --timeout=30s 2>/dev/null || true
    fi

    # Delete namespace
    echo "  Deleting namespace $ns..."
    oc delete namespace --force $ns --ignore-not-found --timeout=10s || true

    echo "  Waiting for namespace deletion..."
    sleep 2

    # Check if namespace is stuck in Terminating state and force cleanup
    echo "  Checking namespace status..."
    local ns_status=$(oc get ns $ns -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    echo "  Status: $ns_status"

    if [[ "$ns_status" == "Terminating" ]]; then
      echo "  Namespace $ns is stuck in Terminating state, performing cleanup..."

      # Clear stale APIs first to fix NamespaceDeletionDiscoveryFailure
      cleanup_stale_apiservices

      # Check if webhooks are the problem
      local webhook_error=$(oc get namespace $ns -o json 2>/dev/null | jq -r '.status.conditions[] | select(.type == "NamespaceDeletionContentFailure") | .message' | grep -i "webhook" || echo "")

      if [[ -n "$webhook_error" ]]; then
        echo "    Webhook blocking deletion detected, removing webhooks..."
        # Delete both validating and mutating webhooks that reference this namespace
        for webhook_type in validatingwebhookconfigurations mutatingwebhookconfigurations; do
          for webhook in $(oc get $webhook_type -o json | jq -r --arg ns "$ns" '.items[] | select(.webhooks[]?.clientConfig.service.namespace == $ns) | .metadata.name'); do
            echo "      Deleting $webhook_type: $webhook"
            oc delete $webhook_type "$webhook" 2>/dev/null || true
          done
        done
      else
        echo "    No webhook issue detected, removing namespace finalizers..."
      fi

      # Remove namespace finalizers if any
      oc patch namespace $ns -p '{"spec":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    fi
  done
}

function delete_crds (){
  # Delete all the RHOAI CRDs
  oc delete crd kfdefs.kfdef.apps.kubeflow.org --ignore-not-found
  oc delete crd acceleratorprofiles.dashboard.opendatahub.io --ignore-not-found
  oc delete crd hardwareprofiles.dashboard.opendatahub.io --ignore-not-found
  oc delete crd hardwareprofiles.infrastructure.opendatahub.io --ignore-not-found
  oc delete crd datascienceclusters.datasciencecluster.opendatahub.io --ignore-not-found
  oc delete crd datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io  --ignore-not-found
  oc delete crd dscinitializations.dscinitialization.opendatahub.io  --ignore-not-found
  oc delete crd featuretrackers.features.opendatahub.io  --ignore-not-found
  oc delete crd modelregistries.modelregistry.opendatahub.io  --ignore-not-found
  oc delete crd odhapplications.dashboard.opendatahub.io  --ignore-not-found
  oc delete crd odhdashboardconfigs.opendatahub.io  --ignore-not-found
  oc delete crd odhdocuments.dashboard.opendatahub.io  --ignore-not-found
  oc delete crd odhquickstarts.console.openshift.io --ignore-not-found
  oc delete crd trustyaiservices.trustyai.opendatahub.io --ignore-not-found
  oc delete crd lmevaljobs.trustyai.opendatahub.io --ignore-not-found
  oc delete crd trustyaiservices.trustyai.opendatahub.io.trustyai.opendatahub.io --ignore-not-found
  oc delete crd guardrailsorchestrators.trustyai.opendatahub.io --ignore-not-found
  oc delete crd inferenceservices.serving.kserve.io --ignore-not-found
  oc delete crd inferencegraphs.serving.kserve.io --ignore-not-found
  oc delete crd servingruntimes.serving.kserve.io --ignore-not-found
  delete_finalizers_using_namespace notebooks.kubeflow.org
  delete_resources notebooks.kubeflow.org delete_finalizers
  oc delete crd notebooks.kubeflow.org --ignore-not-found
  oc delete crd accounts.nim.opendatahub.io --ignore-not-found  --ignore-not-found
  oc delete crd servicemeshes.services.platform.opendatahub.io --ignore-not-found

  # Delete all the ODH/RHOAI DSC Component CRDs
  oc delete crd -l operators.coreos.com/rhods-operator.redhat-ods-operator --ignore-not-found
  oc delete crd -l operators.coreos.com/rhods-operator.opendatahub-operators --ignore-not-found
  delete_finalizers_using_namespace kueues.components.platform.opendatahub.io
  delete_resources kueues.components.platform.opendatahub.io delete_finalizers
  oc delete crd kueues.components.platform.opendatahub.io --ignore-not-found

  # Delete all the CodeFlare CRDs
  oc delete crd appwrappers.workload.codeflare.dev --ignore-not-found
  oc delete crd quotasubtrees.quota.codeflare.dev --ignore-not-found
  oc delete crd schedulingspecs.workload.codeflare.dev --ignore-not-found

  # Delete all the Ray CRDs
  oc delete crd rayclusters.ray.io --ignore-not-found
  oc delete crd rayjobs.ray.io --ignore-not-found
  oc delete crd rayservices.ray.io --ignore-not-found

  # Delete all CRDs created by data-science-pipelines-operator (Argo Workflows, Kubeflow Pipelines ScheduledWorkflows, ...)
  oc delete crd -l app.kubernetes.io/part-of=data-science-pipelines-operator -l app.opendatahub.io/data-science-pipelines-operator=true --ignore-not-found

  # Delete Llama Stack CRDs
  oc delete crd llamastackdistributions.llamastack.io --ignore-not-found

  # Delete the MLFlow CRDs
  oc delete crd mlflows.mlflow.opendatahub.io --ignore-not-found
  oc delete crd mlflowoperators.components.platform.opendatahub.io --ignore-not-found

  # Delete Trainer V2 CRDs
  oc delete crd trainjobs.trainer.kubeflow.org --ignore-not-found
  oc delete crd trainingruntimes.trainer.kubeflow.org --ignore-not-found
  oc delete crd clustertrainingruntimes.trainer.kubeflow.org --ignore-not-found

  # Delete the Models As A Service CRDs
  oc delete crd modelsasservices.components.platform.opendatahub.io --ignore-not-found
}

function delete_olm_resources() {
  local ns="${1}"
  local name="${2}"
  local csv="${3}"

  # Delete Subscriptions
  for sub in $(oc get sub -n "${ns}" -o json | jq -r --arg name "${name}" '.items[] | select(.metadata.name | test($name)) | .metadata.name'); do
    oc delete Subscription "${sub}" -n "${ns}"
  done

  # Delete Install Plans
  for ip in $(oc get installplan -n "${ns}" -o json | jq -r --arg name "${csv}" '.items[] | select(.spec.clusterServiceVersionNames[]? | test($name)) | .metadata.name'); do
    oc delete InstallPlan "${ip}" -n "${ns}"
  done

  # Delete CSVs
  for csv in $(oc get csv -n "${ns}" -o json | jq -r --arg name "${csv}" '.items[] | select(.metadata.name | test($name)) | .metadata.name'); do
    oc delete ClusterServiceVersion "${csv}" -n "${ns}"
  done
}

function delete_marketplace_resources() {
  local name="${1}"
  local resources

  # Inspired by https://access.redhat.com/solutions/6459071
  resources=$(oc get job -n openshift-marketplace -o json | jq -r --arg name "${name}" '.items[] | select(.spec.template.spec.containers[].env // [] | .[].value | test($name)) | .metadata.name' | paste -sd ' ' -)
  if [[ -n "${resources}" ]]; then
    echo "Deleting markeplace jobs ${resources}"
    oc delete job -n openshift-marketplace ${resources}
    echo "Deleting marketplace configmaps ${resources}"
    oc delete configmap -n openshift-marketplace ${resources}
  else
    echo "No marketplace resources were found for '${name}'"
  fi
}

function cleanup_authorino() {
  delete_resource_with_timeout "authorino" "authorino" "kuadrant-system"
  oc delete job -n openshift-operators authconfig-migrator --ignore-not-found

  delete_olm_resources "openshift-operators" "authorino-operator" "authorino-operator"
  delete_marketplace_resources "authorino-operator-bundle"

  oc delete crd authconfigs.authorino.kuadrant.io  --ignore-not-found
  oc delete crd authorinos.operator.authorino.kuadrant.io  --wait=false --ignore-not-found
}

function cleanup_serverless() {
  delete_resources "knativeservings.operator.knative.dev"
  delete_resources "knativeeventings.operator.knative.dev"
  delete_resources "knativekafkas.operator.serverless.openshift.io"

  delete_olm_resources "openshift-serverless" "serverless-operator" "serverless-operator"
  delete_marketplace_resources "serverless-operator-bundle"

  delete_webhooks "knativeeventings"
  delete_webhooks "knativeservings"
  delete_webhooks "knativekafkas"
  delete_webhooks "knative"

  delete_namespace_with_cleanup "knative-serving" "knative-eventing" "knative-serving-ingress" "openshift-serverless"

  oc delete crd knativeeventings.operator.knative.dev --ignore-not-found
  oc delete crd knativeservings.operator.knative.dev --ignore-not-found
  oc delete crd knativekafkas.operator.serverless.openshift.io --ignore-not-found
}

function cleanup_servicemesh() {
  delete_resources "servicemeshcontrolplanes.maistra.io"
  delete_resources "servicemeshmemberrolls.maistra.io"
  delete_resources "servicemeshmembers.maistra.io"

  delete_olm_resources "openshift-operators" "servicemeshoperator" "servicemeshoperator"
  delete_marketplace_resources "istio-operator-bundle"

  delete_webhooks "istio-system"

  delete_namespace_with_cleanup "istio-system"

  oc delete crd servicemeshcontrolplanes.maistra.io --ignore-not-found
  oc delete crd servicemeshmemberrolls.maistra.io --ignore-not-found
  oc delete crd servicemeshmembers.maistra.io --ignore-not-found
}

function cleanup_servicemesh3() {
  # Delete Gateway API resources (both RHOAI-specific and OpenShift default)
  echo "Deleting Gateway API resources..."
  oc delete gateways.gateway.networking.k8s.io data-science-gateway --force --ignore-not-found 2>/dev/null || true
  oc delete gatewayclasses.gateway.networking.k8s.io data-science-gateway-class --force --ignore-not-found 2>/dev/null || true
  oc delete gatewayclasses.gateway.networking.k8s.io openshift-default --ignore-not-found 2>/dev/null || true

  # Delete any Istio resources before removing the operator
  echo "Deleting Istio resources..."
  oc delete istios.sailoperator.io --all --all-namespaces --ignore-not-found 2>/dev/null || true

  # Clean up OLM resources (subscription and CSV)
  # Note: servicemesh3 may be managed by OpenShift Ingress Operator and will be recreated
  # unless openshift-default GatewayClass is removed first
  echo "Deleting servicemeshoperator3 subscription..."
  oc delete subscription servicemeshoperator3 -n openshift-operators --force --grace-period=0 --ignore-not-found 2>/dev/null || true

  echo "Deleting servicemeshoperator3 CSVs..."
  for csv in $(oc get csv -n openshift-operators -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("servicemeshoperator3")) | .metadata.name' 2>/dev/null); do
    echo "  Removing finalizers from CSV: ${csv}"
    oc patch csv "${csv}" -n openshift-operators --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null || true
    echo "  Deleting CSV: ${csv}"
    oc delete csv "${csv}" -n openshift-operators --force --grace-period=0 --ignore-not-found 2>/dev/null || true
  done

  # Delete Istio and Sail Operator CRDs
  echo "Deleting Istio and Sail Operator CRDs..."
  # Delete all instances of sailoperator resources before deleting CRDs
  for crd in istios.sailoperator.io istiorevisions.sailoperator.io istiorevisiontags.sailoperator.io istiocnis.sailoperator.io ztunnels.sailoperator.io; do
    if oc get crd "${crd}" &>/dev/null; then
      echo "  Deleting all instances of ${crd}"
      delete_resources "${crd}"
      echo "  Deleting CRD ${crd}"
      oc delete crd "${crd}" --ignore-not-found
    fi
  done
  oc delete crd authorizationpolicies.security.istio.io --ignore-not-found
  oc delete crd destinationrules.networking.istio.io --ignore-not-found
  oc delete crd envoyfilters.networking.istio.io --ignore-not-found
  oc delete crd gateways.networking.istio.io --ignore-not-found
  oc delete crd peerauthentications.security.istio.io --ignore-not-found
  oc delete crd proxyconfigs.networking.istio.io --ignore-not-found
  oc delete crd requestauthentications.security.istio.io --ignore-not-found
  oc delete crd serviceentries.networking.istio.io --ignore-not-found
  oc delete crd sidecars.networking.istio.io --ignore-not-found
  oc delete crd telemetries.telemetry.istio.io --ignore-not-found
  oc delete crd virtualservices.networking.istio.io --ignore-not-found
  oc delete crd wasmplugins.extensions.istio.io --ignore-not-found
  oc delete crd workloadentries.networking.istio.io --ignore-not-found
  oc delete crd workloadgroups.networking.istio.io --ignore-not-found
  oc delete crd istiocsrs.operator.openshift.io --ignore-not-found

  echo "ServiceMesh operator v3 cleanup completed"
}

function cleanup_clusterobservability() {
  delete_resources "alertmanagerconfigs.monitoring.rhobs"
  delete_resources "alertmanagers.monitoring.rhobs"
  delete_resources "monitoringstacks.monitoring.rhobs"
  delete_resources "perses.perses.dev"
  delete_resources "persesdashboards.perses.dev"
  delete_resources "persesdatasources.perses.dev"
  delete_resources "podmonitors.monitoring.rhobs"
  delete_resources "probes.monitoring.rhobs"
  delete_resources "prometheusagents.monitoring.rhobs"
  delete_resources "prometheuses.monitoring.rhobs"
  delete_resources "scrapeconfigs.monitoring.rhobs"
  delete_resources "servicemonitors.monitoring.rhobs"
  delete_resources "thanosqueriers.monitoring.rhobs"
  delete_resources "thanosrulers.monitoring.rhobs"
  delete_resources "uiplugins.observability.openshift.io"

  delete_olm_resources "openshift-cluster-observability-operator" "cluster-observability-operator" "cluster-observability-operator"
  delete_marketplace_resources "cluster-observability-operator-bundle"

  delete_namespace_with_cleanup "openshift-cluster-observability-operator"

  oc delete crd alertmanagerconfigs.monitoring.rhobs --ignore-not-found
  oc delete crd alertmanagers.monitoring.rhobs --ignore-not-found
  oc delete crd monitoringstacks.monitoring.rhobs --ignore-not-found
  oc delete crd perses.perses.dev --ignore-not-found
  oc delete crd persesdashboards.perses.dev --ignore-not-found
  oc delete crd persesdatasources.perses.dev --ignore-not-found
  oc delete crd podmonitors.monitoring.rhobs --ignore-not-found
  oc delete crd probes.monitoring.rhobs --ignore-not-found
  oc delete crd prometheusagents.monitoring.rhobs --ignore-not-found
  oc delete crd prometheuses.monitoring.rhobs --ignore-not-found
  oc delete crd scrapeconfigs.monitoring.rhobs --ignore-not-found
  oc delete crd servicemonitors.monitoring.rhobs --ignore-not-found
  oc delete crd thanosqueriers.monitoring.rhobs --ignore-not-found
  oc delete crd thanosrulers.monitoring.rhobs --ignore-not-found
  oc delete crd uiplugins.observability.openshift.io --ignore-not-found
}

function cleanup_tempo() {
  delete_resources "tempomonolithics.tempo.grafana.com"
  delete_resources "tempostacks.tempo.grafana.com"

  delete_olm_resources "openshift-tempo-operator" "tempo-operator" "tempo-operator"
  delete_marketplace_resources "tempo-operator-bundle"

  delete_webhooks "mtempostack"

  delete_namespace_with_cleanup "openshift-tempo-operator"

  oc delete crd tempomonolithics.tempo.grafana.com --ignore-not-found
  oc delete crd tempostacks.tempo.grafana.com --ignore-not-found
}

function cleanup_opentelemetry() {
  delete_resources "instrumentations.opentelemetry.io"
  delete_resources "opampbridges.opentelemetry.io"
  delete_resources "opentelemetrycollectors.opentelemetry.io"
  delete_resources "targetallocators.opentelemetry.io"

  delete_olm_resources "openshift-opentelemetry-operator" "opentelemetry-operator" "opentelemetry-operator"
  delete_marketplace_resources "opentelemetry-operator-bundle"

  delete_webhooks "minstrumentation"
  delete_webhooks "mopampbridge"
  delete_webhooks "mopentelemetrycollectorbeta"
  delete_webhooks "mpod"
  delete_webhooks "mtargetallocatorbeta"

  delete_namespace_with_cleanup "openshift-opentelemetry-operator"

  oc delete crd instrumentations.opentelemetry.io --ignore-not-found
  oc delete crd opampbridges.opentelemetry.io --ignore-not-found
  oc delete crd opentelemetrycollectors.opentelemetry.io --ignore-not-found
  oc delete crd targetallocators.opentelemetry.io --ignore-not-found
}

function cleanup_connectivitylink() {
  delete_resource_with_timeout "kuadrant" "kuadrant" "kuadrant-system"
  delete_resources "connectivitylinks.connectivity.redhat.com"
  delete_resources "kuadrants.kuadrant.io"

  # Clean up the main Kuadrant operator and its dependencies
  delete_olm_resources "kuadrant-system" "rhcl-operator" "rhcl-operator"
  delete_olm_resources "kuadrant-system" "dns-operator" "dns-operator"
  delete_olm_resources "kuadrant-system" "limitador-operator" "limitador-operator"
  delete_olm_resources "kuadrant-system" "authorino-operator" "authorino-operator"

  delete_marketplace_resources "kuadrant-operator-bundle"
  delete_marketplace_resources "dns-operator-bundle"
  delete_marketplace_resources "limitador-operator-bundle"
  delete_marketplace_resources "authorino-bundle"

  delete_namespace_with_cleanup "kuadrant-system"

  oc delete crd connectivitylinks.connectivity.redhat.com --ignore-not-found
}

function cleanup_kueue() {
  cleanup_stale_apiservices
  delete_resources "kueues.kueue.openshift.io"

  delete_olm_resources "openshift-kueue-operator" "kueue-operator" "kueue-operator"
  delete_marketplace_resources "kueue-operator-bundle"

  delete_namespace_with_cleanup "openshift-kueue-operator"

  oc delete crd kueues.kueue.openshift.io --ignore-not-found
    # Delete all the Kueue CRDs
  delete_finalizers_using_namespace admissionchecks.kueue.x-k8s.io
  delete_resources admissionchecks.kueue.x-k8s.io delete_finalizers
  oc delete crd admissionchecks.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace cohorts.kueue.x-k8s.io
  delete_resources cohorts.kueue.x-k8s.io delete_finalizers
  oc delete crd cohorts.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace clusterqueues.kueue.x-k8s.io
  delete_resources clusterqueues.kueue.x-k8s.io delete_finalizers
  oc delete crd clusterqueues.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace localqueues.kueue.x-k8s.io
  delete_resources localqueues.kueue.x-k8s.io delete_finalizers
  oc delete crd localqueues.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace multikueueclusters.kueue.x-k8s.io
  delete_resources multikueueclusters.kueue.x-k8s.io delete_finalizers
  oc delete crd multikueueclusters.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace multikueueconfigs.kueue.x-k8s.io
  delete_resources multikueueconfigs.kueue.x-k8s.io delete_finalizers
  oc delete crd multikueueconfigs.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace provisioningrequestconfigs.kueue.x-k8s.io
  delete_resources provisioningrequestconfigs.kueue.x-k8s.io delete_finalizers
  oc delete crd provisioningrequestconfigs.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace resourceflavors.kueue.x-k8s.io
  delete_resources resourceflavors.kueue.x-k8s.io delete_finalizers
  oc delete crd resourceflavors.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace topologies.kueue.x-k8s.io
  delete_resources topologies.kueue.x-k8s.io delete_finalizers
  oc delete crd topologies.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace workloadpriorityclasses.kueue.x-k8s.io
  delete_resources workloadpriorityclasses.kueue.x-k8s.io delete_finalizers
  oc delete crd workloadpriorityclasses.kueue.x-k8s.io --ignore-not-found
  delete_finalizers_using_namespace workloads.kueue.x-k8s.io
  delete_resources workloads.kueue.x-k8s.io delete_finalizers
  oc delete crd workloads.kueue.x-k8s.io --ignore-not-found --ignore-not-found
}

function cleanup_leaderworkerset() {
  delete_resource_with_timeout "leaderworkersetoperator" "cluster" "openshift-lws-operator"
  delete_resources "leaderworkersetoperators.operator.openshift.io"
  delete_resources "leaderworkersets.leaderworkerset.x-k8s.io"

  delete_olm_resources "openshift-lws-operator" "leader-worker-set" "leader-worker-set"
  delete_marketplace_resources "leader-worker-set-bundle"

  delete_webhooks "lws"

  delete_namespace_with_cleanup "openshift-lws-operator"

  oc delete crd leaderworkersetoperators.operator.openshift.io --ignore-not-found
  oc delete crd leaderworkersets.leaderworkerset.x-k8s.io --ignore-not-found
}

function cleanup_certmanager() {
  # Clean up both community cert-manager (in openshift-operators) and Red Hat cert-manager (in cert-manager-operator)
  delete_olm_resources "openshift-operators" "cert-manager" "cert-manager"
  delete_olm_resources "cert-manager-operator" "openshift-cert-manager-operator" "cert-manager-operator"
  delete_marketplace_resources "openshift-cert-manager-operator-bundle"

  delete_resources "certificaterequests.cert-manager.io"
  delete_resources "certificates.cert-manager.io"
  # delete_resources "certmanagers.operator.openshift.io"
  delete_resources "challenges.acme.cert-manager.io"
  delete_resources "clusterissuers.cert-manager.io"
  delete_resources "issuers.cert-manager.io"
  delete_resources "istiocsrs.operator.openshift.io"
  delete_resources "orders.acme.cert-manager.io"

  delete_webhooks "cert-manager"

  delete_namespace_with_cleanup "cert-manager-operator" "cert-manager"

  oc delete crd certificaterequests.cert-manager.io --ignore-not-found
  oc delete crd certificates.cert-manager.io --ignore-not-found
  # oc delete crd certmanagers.operator.openshift.io --ignore-not-found
  oc delete crd challenges.acme.cert-manager.io --ignore-not-found
  oc delete crd clusterissuers.cert-manager.io --ignore-not-found
  oc delete crd issuers.cert-manager.io --ignore-not-found
  oc delete crd istiocsrs.operator.openshift.io --ignore-not-found
  oc delete crd orders.acme.cert-manager.io --ignore-not-found
}

function cleanup_cma() {
  delete_resources "scaledobjects.keda.sh"
  delete_resources "scaledjobs.keda.sh"
  delete_resources "triggerauthentications.keda.sh"
  delete_resources "clustertriggerauthentications.keda.sh"
  delete_resources "kedacontrollers.keda.sh"

  delete_olm_resources "openshift-keda" "openshift-custom-metrics-autoscaler-operator" "custom-metrics-autoscaler"
  delete_marketplace_resources "custom-metrics-autoscaler-operator-bundle"

  delete_webhooks "keda"
  delete_webhooks "custom-metrics-autoscaler"

  delete_namespace_with_cleanup "openshift-keda"

  oc delete crd scaledobjects.keda.sh --ignore-not-found
  oc delete crd scaledjobs.keda.sh --ignore-not-found
  oc delete crd triggerauthentications.keda.sh --ignore-not-found
  oc delete crd clustertriggerauthentications.keda.sh --ignore-not-found
  oc delete crd kedacontrollers.keda.sh --ignore-not-found
}

function cleanup_jobset() {
  delete_resources "jobsetoperators.operator.openshift.io"

  delete_olm_resources "openshift-jobset-operator" "job-set" "jobset-operator"
  delete_marketplace_resources "jobset-operator-bundle"

  delete_webhooks "jobset"

  delete_namespace_with_cleanup "openshift-jobset-operator"

  oc delete crd jobsetoperators.operator.openshift.io --ignore-not-found
}

# Delete the ODH/RHOAI operator
delete_olm_resources "opendatahub-operators" "rhoai-operator-dev" "opendatahub-operator"
delete_olm_resources "redhat-ods-operator" "rhoai-operator-dev" "rhods-operator"

#if [ ${INSTALLATION_TYPE} == "operator" ]; then

    #remove_all_dependencies
#fi

# Keyword 'odh-operator-bundle' covers ODH as well as RHOAI
delete_marketplace_resources "odh-operator-bundle"

# Keep User Resources if -K option is enabled
if [ ${KEEP_USER_RESOURCES} = "true" ]; then
   echo "-K option is set, so skipping the removal of user resources (data science projects, CRs, ...)"
else
  echo "Removing all RHOAI user resources forcefully to be sure there are no leftover resources on the cluster. Please, be patient..."

  # Delete all the KfDef instances (RHOAI 1.x) - the CRDs might not have been installed
  oc delete kfdef --all -n ${RHODS_NOTEBOOKS_NAMESPACE} --ignore-not-found || true
  oc delete kfdef --all -n ${RHODS_MONITORING_NAMESPACE} --ignore-not-found || true
  oc delete kfdef --all -n ${RHODS_APPS_NAMESPACE} --ignore-not-found || true

  # Delete finalizers in RHOAI resources so they can be deleted after
  delete_finalizers_using_namespace DataSciencePipelinesApplication
  delete_finalizers_using_namespace clusterqueue.kueue.x-k8s.io
  delete_finalizers_using_namespace resourceflavor.kueue.x-k8s.io
  delete_finalizers_using_namespace workload.kueue.x-k8s.io
  delete_finalizers_using_namespace rayclusters.ray.io

  # Cleanup of RHOAI resources
  delete_resources InferenceService delete_finalizers
  delete_resources AcceleratorProfile
  delete_resources hardwareprofiles.dashboard.opendatahub.io
  delete_resources hardwareprofiles.infrastructure.opendatahub.io
  delete_resources DataSciencePipelinesApplication
  delete_resources FeatureTracker
  delete_resources modelregistries.modelregistry.opendatahub.io
  delete_resources OdhApplication
  delete_resources OdhDashboardConfig
  delete_resources OdhDocument
  delete_resources PyTorchJob
  delete_finalizers clustertrainingruntimes.trainer.kubeflow.org
  delete_resources trainjobs.trainer.kubeflow.org
  delete_resources trainingruntimes.trainer.kubeflow.org
  delete_resources clustertrainingruntimes.trainer.kubeflow.org
  delete_resources RayCluster
  delete_resources TrustyAIService
  delete_resources LMEvalJob
  delete_resources clusterqueues.kueue.x-k8s.io delete_finalizers
  delete_resources resourceflavors.kueue.x-k8s.io delete_finalizers
  delete_resources workloadpriorityclasses.kueue.x-k8s.io delete_finalizers
  delete_resources workloads.kueue.x-k8s.io delete_finalizers
  delete_resources kubeflow.org.Notebook
  delete_resources DataScienceCluster delete_finalizers
  delete_resources CodeFlare
  delete_resources Dashboard
  delete_resources DataSciencePipelines
  delete_resources FeastOperator
  delete_resources Kserve
  delete_resources kueues.components.platform.opendatahub.io
  delete_resources ModelController
  delete_resources ModelMeshServing
  delete_resources ModelRegistry
  delete_resources Ray
  delete_resources TrainingOperator
  delete_resources Trainer
  delete_resources TrustyAI
  delete_resources GuardrailsOrchestrator
  delete_resources Workbenches
  delete_resources DSCInitialization delete_finalizers
  delete_resources Auth
  delete_resources Account
  delete_resources LlamaStackDistribution
  delete_resources servicemeshes.services.platform.opendatahub.io
  delete_resources gatewayconfigs.services.platform.opendatahub.io
  delete_resources mlflows.mlflow.opendatahub.io
  delete_resources mlflowoperators.components.platform.opendatahub.io
  delete_resources modelsasservices.modelsasservice.opendatahub.io

  # Delete kuberay webhooks
  delete_webhooks "kuberay"

  # Delete the Kueue validating webhook
  delete_webhooks "kueue-.*-webhook-configuration"

  # Delete the Training operator validating webhook
  delete_webhooks "kubeflow-validator.training-operator.kubeflow.org"

  # Delete the Trainer V2 validating webhook
  delete_webhooks "validator.trainer.kubeflow.org"

  # Delete any other opendatahub webhooks
  delete_webhooks "opendatahub"
fi

# WARNING: ServiceMesh3 is managed by OpenShift Ingress Operator (not RHOAI)
# Deleting it will remove the openshift-default GatewayClass and disable OpenShift's
# default gateway functionality. Only uncomment if you want to completely remove servicemesh3.
# RHOAI-specific gateway resources (data-science-gateway, data-science-gateway-class) will be
# removed when called via the cleanup loop at the end of this script.
#cleanup_servicemesh3

# Keep CRDs if -k option is enabled
if [ ${KEEP_CRDS} = "true" ]; then
   echo "-k or -K option is set, so skipping CRD removal."
else
   delete_crds
fi

# Delete all the RHODS namespaces except the ones with user resources
delete_namespace_with_cleanup ${RHODS_APPS_NAMESPACE} ${RHODS_AUTH_PROVIDER_NAMESPACE} ${RHODS_MONITORING_NAMESPACE} \
                              ${RHODS_OPERATOR_NAMESPACE} ${OPENDATAHUB_NAMESPACE} ${OPENDATAHUB_OPERATORS_NAMESPACE} \
                              ${OPENDATAHUB_OPERATOR_SYSTEM_NAMESPACE} ${OPENDATAHUB_AUTH_PROVIDER_NAMESPACE} \
                              ${CUSTOM_OPERATOR_NAMESPACE} ${CUSTOM_APPS_NAMESPACE}

# Delete also the project with user resources if -K option is not enabled
if [ ${KEEP_USER_RESOURCES} = "false" ]; then
  delete_namespace_with_cleanup ${RHODS_NOTEBOOKS_NAMESPACE} ${CUSTOM_WB_NAMESPACE} ${RHODS_MODEL_REGISTRY_NAMESPACE} ${OPENDATAHUB_MODEL_REGISTRY_NAMESPACE}
fi

for operator in ${ADDITIONAL_OPERATORS}; do
  case "${operator}" in
    "authorino")
      echo "Cleanup additional operator authorino"
      cleanup_authorino
      ;;
    "serverless")
      echo "Cleanup additional operator serverless"
      cleanup_serverless
      ;;
    "servicemesh")
      echo "Cleanup additional operator servicemesh"
      cleanup_servicemesh
      ;;
    "servicemesh3")
      echo "Cleanup additional operator servicemesh3"
      cleanup_servicemesh3
      ;;
    "clusterobservability")
      echo "Cleanup additional operator clusterobservability"
      cleanup_clusterobservability
      ;;
    "tempo")
      echo "Cleanup additional operator tempo"
      cleanup_tempo
      ;;
    "opentelemetry")
      echo "Cleanup additional operator opentelemetry"
      cleanup_opentelemetry
      ;;
    "kueue")
      echo "Cleanup additional operator kueue"
      cleanup_kueue
      ;;
    "cma")
      echo "Cleanup additional operator cma"
      cleanup_cma
      ;;
    "certmanager")
      echo "Cleanup additional operator certmanager"
      cleanup_certmanager
      ;;
    "connectivitylink")
      echo "Cleanup additional operator connectivitylink"
      cleanup_connectivitylink
      ;;
    "leaderworkerset")
      echo "Cleanup additional operator leaderworkerset"
      cleanup_leaderworkerset
      ;;
    "jobset")
      echo "Cleanup additional operator jobset"
      cleanup_jobset
      ;;
    *)
      echo "ERROR: Unknown additional operator '${operator}'"
      exit 1
      ;;
  esac
done

