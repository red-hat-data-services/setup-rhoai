secrets=$(mktemp -d)
oc extract secret/pull-secret -n openshift-config --to="${secrets}"
if ! grep brew.registry.redhat.io < "${secrets}"/.dockerconfigjson
then
  echo adding brew pull secret
  sed -i 's/^{"auths":{/{"auths":{"brew.registry.redhat.io":{"auth":"'$(cat ~/.ssh/.brew_token)'"},/' "${secrets}"/.dockerconfigjson
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="${secrets}"/.dockerconfigjson
fi
rm -rf "${secrets}"
