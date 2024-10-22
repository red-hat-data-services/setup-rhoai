# Install OpenShift AI dev build using a brew index image
* Make sure you have the "oc" cli installed
* Make sure you are logged in to the cluster from the cli as an admin
* Uninstall Openshift AI completely if it is installed
* Store the quay token in a file at this location - ~/.ssh/.quay_ro_token
* Update the required index image in config/catalogsource.yaml as the value of "spec.image" field
* Run setup_rhoai.sh