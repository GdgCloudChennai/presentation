#!/bin/bash -e

#Input
export IN_ENVI="demo"
export IN_ORGI="gdg"
export IN_TEAM="gdgc"
export IN_SUBD="devfest2019"
export IN_SERVICE_PROJECT_ID="devfest2019-gke-$IN_ENVI"

export IN_NW_NAME="$IN_ORGI-$IN_SUBD-nw-$IN_ENVI"
export IN_NW_DESC="Nework used for $IN_ORGI $IN_SUBD"

export IN_SN_NAME="$IN_ORGI-$IN_SUBD-sn-$IN_ENVI"
export IN_SN_DESC="Subnet used for $IN_ORGI $IN_SUBD"
export IN_SN_CIDR="10.160.0.0/20"

export IN_GKE_NAME="$IN_ORGI-$IN_SUBD-cluster-$IN_ENVI"

export IN_IP_NAME="$IN_SUBD-app-ip-$IN_ENVI"
export IN_IP_DESC="IP used for $IN_ORGI $IN_SUBD"

export IN_DEPL_YAML="$IN_ORGI-df2019-k8s-depl-$IN_ENVI.yaml"

export IN_READ_ONLY=""

# function

function prerequisites() {

    echo -e "\nPrerequisting..."
    command -v gcloud >/dev/null 2>&1 || \
    { echo >&2 "Require gcloud but it's not installed.  Aborting."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || \
    { echo >&2 "Require kubectl but it's not installed.  Aborting."; exit 1; }

}


function enable_api() {

  SERVICE=$1
  if [[ $(gcloud services list --format="value(serviceConfig.name)" \
                                --filter="serviceConfig.name:$SERVICE" 2>&1) != \
                                "$SERVICE" ]]; then
    echo "Enabling $SERVICE"
    gcloud services enable "$SERVICE" --project=$IN_SERVICE_PROJECT_ID
  else
    echo "$SERVICE is already enabled"
  fi

}


function deploy_network() {
    
    echo -e "\nDeploying network..."
    gcloud compute networks create $IN_NW_NAME \
    --project=$IN_SERVICE_PROJECT_ID \
    --description="$IN_NW_DESC" \
    --subnet-mode="custom"
    

    echo -e "\nDeploying subnet..."
    gcloud compute networks subnets create $IN_SN_NAME \
    --project=$IN_SERVICE_PROJECT_ID \
    --description="$IN_SN_DESC" \
    --network="$IN_NW_NAME" \
    --range="$IN_SN_CIDR" \
    --region="asia-south1"

}

function deploy_ip() {

    echo -e "\nDeploying IP address..."
    gcloud compute addresses create $IN_IP_NAME \
    --global \
    --description="$IN_IP_DESC" \
    --project=$IN_SERVICE_PROJECT_ID

}


function deploy_cluster() {

    echo -e "\nDeploying cluster..."
    gcloud container clusters create $IN_GKE_NAME \
    --project=$IN_SERVICE_PROJECT_ID \
    --network="projects/$IN_SERVICE_PROJECT_ID/global/networks/$IN_NW_NAME" \
    --subnetwork="projects/$IN_SERVICE_PROJECT_ID/regions/asia-south1/subnetworks/$IN_SN_NAME" \
    --enable-ip-alias \
    --region="asia-south1" --no-enable-basic-auth \
    --cluster-version="1.13.7-gke.8" \
    --machine-type="n1-standard-2" \
    --image-type="COS" --disk-type="pd-standard" --disk-size "10" \
    --metadata disable-legacy-endpoints=true \
    --num-nodes="1" \
    --default-max-pods-per-node="110" --enable-autoscaling --min-nodes "1" --max-nodes "5" \
    --enable-stackdriver-kubernetes \
    --addons="HorizontalPodAutoscaling,HttpLoadBalancing" \
    --enable-autoupgrade --enable-autorepair \
    --maintenance-window="21:30" \
    --labels="team=$IN_TEAM,envirnment=$IN_ENV"
    
}

function get_cluster_cred() {

    echo -e "\nGetting credentials..."
    gcloud beta container clusters get-credentials $IN_GKE_NAME \
    --region="asia-south1" \
    --project=$IN_SERVICE_PROJECT_ID
}

# BEGIN - main procedure

echo -e "\nPackage deploy resources for $IN_ORGI $IN_SUBD"

echo "Do you want in read only mode (no deploy)?"
read -r IN_READ_ONLY

echo -e "\nBelow are the parameter:"
echo "Your read only paramter: $IN_READ_ONLY"
echo "Environment: $IN_ENVI"
echo "Organization: $IN_ORGI"
echo "Team: $IN_TEAM"
echo "Subdivision: $IN_SUBD"
echo "Sevice project ID: $IN_SERVICE_PROJECT_ID"

echo "Network name: $IN_NW_NAME"
echo "Network description: $IN_NW_DESC"

echo "Subnetwork name: $IN_SN_NAME"
echo "Subnet description: $IN_SN_DESC"
echo "Subnet CIDR: $IN_SN_CIDR"

echo "Cluster name: $IN_GKE_NAME"

echo "IP address name: $IN_IP_NAME"
echo "IP address description: $IN_IP_DESC"

echo "k8s deployment file: $IN_DEPL_YAML"

if [[ $IN_READ_ONLY == "n" || $IN_READ_ONLY == "N" ]]
then

    #Call function: to validate prerequisites
    prerequisites

    #Call function: to enable API
    echo -e "\nEnabling APIs..."
    enable_api servicenetworking.googleapis.com
    enable_api container.googleapis.com
    enable_api iam.googleapis.com

    #Call function: to deploy custom VPC etwork
    deploy_network

    #Call funcation:  to deploy IP address
    deploy_ip

    #Call function: to deploy GKE cluster
    deploy_cluster

    #Call function: to get GKE cluster credentials
    get_cluster_cred
    
    #non-arch: To configure k8s and deploying application
    echo -e "\nConfiguring k8s and deploying application..."
    kubectl apply --filename=$IN_DEPL_YAML
    
fi

# END - main procedure