#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
JENKINS_PROJECT=$GUID-jenkins
echo "Setting up Jenkins in project $JENKINS_PROJECT from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student
oc project $JENKINS_PROJECT

oc process -f ./Infrastructure/templates/jenkins-template.yml -p NAMESPACE=$JENKINS_PROJECT | oc create -f - -n $JENKINS_PROJECT

echo "Building the slave"

oc new-build --name=jenkins-slave-maven-appdev -D $'FROM docker.io/openshift/jenkins-slave-maven-centos7:v3.9\nUSER root\nRUN yum -y install skopeo\nUSER 1001' -n $JENKINS_PROJECT
sleep 120

echo "Configuring slave"
# configure kubernetes PodTemplate plugin.
oc new-app -f ./Infrastructure/templates/jenkins-config.yml --param GUID=$GUID -n $JENKINS_PROJECT

echo "Slave configured"


echo 'apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "mlbparks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/cfoskin/appvdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: ./MLBParks/Jenkinsfile
kind: List
metadata: []' | oc create -f - -n $JENKINS_PROJECT

echo 'apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "nationalparks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/cfoskin/appvdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: ./Nationalparks/Jenkinsfile
kind: List
metadata: []' | oc create -f - -n $JENKINS_PROJECT 

echo 'apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "parksmap-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/cfoskin/appvdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: ./ParksMap/Jenkinsfile
kind: List
metadata: []' | oc create -f - -n $JENKINS_PROJECT

echo "setting required envars for the build configs.."
oc set env bc/mlbparks-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $JENKINS_PROJECT
oc set env bc/nationalparks-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $JENKINS_PROJECT
oc set env bc/parksmap-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $JENKINS_PROJECT





