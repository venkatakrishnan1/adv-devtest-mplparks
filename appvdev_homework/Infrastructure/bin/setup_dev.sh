#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
DEV_PROJECT=$GUID-parks-dev
PROD_PROJECT=$GUID-parks-prod

echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n ${DEV_PROJECT}
oc policy add-role-to-user admin system:serviceaccount:$GUID-jenkins:jenkins -n  ${DEV_PROJECT}
oc policy add-role-to-user view system:serviceaccount:default -n  ${DEV_PROJECT}
oc policy add-role-to-group system:image-puller system:serviceaccounts:${PROD_PROJECT} -n ${DEV_PROJECT}

oc project $DEV_PROJECT

oc process -f ./Infrastructure/templates/mongodb-single-template.yml | oc create -f - -n ${DEV_PROJECT}


while : ; do
  oc project ${DEV_PROJECT}
  echo "Checking if Mongodb is Ready..."
  output=$(oc get pods --field-selector=status.phase='Running' | grep 'mongodb' | grep -v 'deploy' | grep '1/1' | awk '{print $2}')
  [[ "${output}" != "1/1" ]] || break #testing here
  echo "...no Sleeping 10 seconds."
  sleep 10
done
echo "Mongodb Deployment complete"

echo "Creating binary build configs.."
oc new-build --binary=true --name="mlbparks" -i=jboss-eap70-openshift:1.7 -n $DEV_PROJECT
oc new-build --binary=true --name="nationalparks" -i=redhat-openjdk18-openshift:1.2 -n $DEV_PROJECT
oc new-build --binary=true --name="parksmap" -i=redhat-openjdk18-openshift:1.2 -n $DEV_PROJECT

echo "Creating Deployment Configs.."
oc new-app $DEV_PROJECT/mlbparks:0.0-0 --name=mlbparks --allow-missing-imagestream-tags=true -n $DEV_PROJECT
oc new-app $DEV_PROJECT/nationalparks:0.0-0 --name=nationalparks --allow-missing-imagestream-tags=true -n $DEV_PROJECT
oc new-app $DEV_PROJECT/parksmap:0.0-0 --name=parksmap --allow-missing-imagestream-tags=true -n $DEV_PROJECT

oc set resources deployment mlbparks  --limits=cpu=100m -n $DEV_PROJECT
oc set resources deployment nationalparks  --limits=cpu=100m -n $DEV_PROJECT
oc set resources deployment mlbparks  --limits=cpu=100m -n $DEV_PROJECT

echo "Setting triggers.."
oc set triggers dc/mlbparks --remove-all -n $DEV_PROJECT
oc set triggers dc/nationalparks --remove-all -n $DEV_PROJECT
oc set triggers dc/parksmap --remove-all -n $DEV_PROJECT


echo "Create Configmaps.."
oc create configmap mlbparks-config --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=MLB Parks (Dev)" -n $DEV_PROJECT

oc create configmap nationalparks-config --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=National Parks (Dev)" -n $DEV_PROJECT

oc create configmap parksmap-config --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=ParksMap (Dev)" -n $DEV_PROJECT

echo "Update the DeploymentConfig to use the configmaps.. "
oc set env dc/mlbparks --from=configmap/mlbparks-config -n $DEV_PROJECT
oc set env dc/nationalparks --from=configmap/nationalparks-config -n $DEV_PROJECT
oc set env dc/parksmap --from=configmap/parksmap-config -n $DEV_PROJECT

echo "Creating services.."
oc expose dc/mlbparks  --port 8080 -n $DEV_PROJECT
oc expose dc/nationalparks  --port 8080 -n $DEV_PROJECT
oc expose dc/parksmap  --port 8080 -n $DEV_PROJECT

echo "Creating labels for backend"
oc label svc/mlbparks type=parksmap-backend -n $DEV_PROJECT
oc label svc/nationalparks type=parksmap-backend -n $DEV_PROJECT



