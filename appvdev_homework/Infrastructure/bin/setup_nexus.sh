#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
NEXUS_PROJECT=${GUID}-nexus
echo "Setting up Nexus in project $NEXUS_PROJECT"
# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:

# To be Implemented by Student
oc project $NEXUS_PROJECT

oc process -f ./Infrastructure/templates/nexus-template.yml | oc create -f - -n $NEXUS_PROJECT 
echo "Waiting for Nexus to deploy..."
sleep 60

while : ; do
  oc project $NEXUS_PROJECT
  echo "Checking if Nexus is Ready..."
  http_code=$(curl -s -o /dev/null -w "%{http_code}" http://$(oc get route nexus3 --template='{{ .spec.host }}')/repository/maven-public/)
  echo "HTTP code returned is: " $http_code
  [[ "$http_code" != "200" ]] || break
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

#configure nexus
echo "retrieving config via curl"
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n $NEXUS_PROJECT)
rm setup_nexus3.sh

oc annotate route nexus3 console.alpha.openshift.io/overview-app-route=true  -n $NEXUS_PROJECT
oc annotate route nexus-registry console.alpha.openshift.io/overview-app-route=false -n $NEXUS_PROJECT
