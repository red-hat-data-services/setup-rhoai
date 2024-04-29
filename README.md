# Install OpenShift AI dev build using a brew index image
* Make sure you have the "oc" cli installed
* Make sure you are logged in to the cluster from the cli as an admin
* Uninstall Openshift AI first if it is installed (just uncomment the first line in setup_rhoai.sh)
* Store the brew token in a file at this location - ~/.ssh/.brew_token
* Update the required index image in config/catalogsource.yaml as the value of "spec.image" field
* Run setup_rhoai.sh