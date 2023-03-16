#!/usr/bin/bash

###################################################
# Enter temp variables here
###################################################

VCENTER_HOSTNAME=192.168.100.50
VCENTER_USERNAME=administrator@vsphere.local
VCENTER_PASSWORD='VMware1!'

export AVI_HOSTNAME=192.168.100.58
export AVI_USERNAME=admin
export AVI_PASSWORD='VMware1!'

K8S_SUP_CLUSTER=Supervisor-Cluster
K8S_CONTENT_LIBRARY=utkg
K8S_STORAGE_POLICY=tanzu
K8S_MGMT_PORTGROUP='DVPG-Management-network'
K8S_WKD0_PORTGROUP='Workload0-VDS-PG'
K8S_WKD1_PORTGROUP='Workload1-VDS-PG'

###################################################

HEADER_CONTENTTYPE="Content-Type: application/json"

content_library_json()
{
	cat <<EOF
{
	"name": "${K8S_CONTENT_LIBRARY}"
}
EOF
}

rm -f /tmp/temp_*.*

################################################
# Get NSXALB CA CERT
###############################################
echo "Getting NSX ALB CA Certificate for  ${AVI_HOSTNAME} ..."
openssl s_client -showcerts -connect ${AVI_HOSTNAME}:443  </dev/null 2>/dev/null|sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > /tmp/temp_avi-ca.cert
if [ ! -s /tmp/temp_avi-ca.cert ]
then
    echo "Error: Could not connect to the NSX ALB endpoint. Please validate!!"
    exit 1
fi
export AVI_CACERT=$(jq -sR . /tmp/temp_avi-ca.cert)

################################################
# Login to VCenter and get Session ID
###############################################
SESSION_ID=$(curl -sk -X POST https://${VCENTER_HOSTNAME}/rest/com/vmware/cis/session --user ${VCENTER_USERNAME}:${VCENTER_PASSWORD} |jq -r '.value')
if [ -z "${SESSION_ID}" ]
then
	echo "Error: Could not connect to the VCenter. Please validate!!"
	exit 1
fi
echo Authenticated successfully to VC with Session ID - ${SESSION_ID} ...
HEADER_SESSIONID="vmware-api-session-id: ${SESSION_ID}"

################################################
# Get cluster details from vCenter
###############################################
echo "Searching for Cluster ${K8S_SUP_CLUSTER} ..."
response=$(curl -ks --write-out "%{http_code}" -X GET  -H "${HEADER_SESSIONID}" https://${VCENTER_HOSTNAME}/api/vcenter/cluster --output /tmp/temp_cluster.json)
if [[ "${response}" -ne 200 ]] ; then
  echo "Error: Could not fetch clusters. Please validate!!"
  exit 1
fi

export TKGClusterID=$(jq -r --arg K8S_SUP_CLUSTER "$K8S_SUP_CLUSTER" '.[]|select(.name == $K8S_SUP_CLUSTER).cluster' /tmp/temp_cluster.json)
#export TKGClusterID=$(jq -r --arg K8S_SUP_CLUSTER "$K8S_SUP_CLUSTER" '.[]|select(.name|contains($K8S_SUP_CLUSTER)).cluster' /tmp/temp_cluster.json)
if [ -z "${TKGClusterID}" ]
then
        echo "Error: Could not fetch cluster - ${K8S_SUP_CLUSTER} . Please validate!!"
        exit 1
fi

################################################
# Get contentlibrary details from vCenter
###############################################
echo "Searching for Content Library ${K8S_CONTENT_LIBRARY} ..."
response=$(curl -ks --write-out "%{http_code}" -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "$(content_library_json)" https://${VCENTER_HOSTNAME}/api/content/library?action=find --output /tmp/temp_contentlib.json)
if [[ "${response}" -ne 200 ]] ; then
  echo "Error: Could not fetch content librarys. Please validate!!"
  exit 1
fi

export TKGContentLibrary=$(jq -r '.[]' /tmp/temp_contentlib.json)
if [ -z "${TKGContentLibrary}" ]
then
        echo "Error: Could not fetch content library - ${K8S_CONTENT_LIBRARY} . Please validate!!"
        exit 1
fi

################################################
# Get stroage policy details from vCenter
###############################################
echo "Searching for Storage Policy ${K8S_STORAGE_POLICY} ..."
response=$(curl -ks --write-out "%{http_code}" -X GET  -H "${HEADER_SESSIONID}" https://${VCENTER_HOSTNAME}/api/vcenter/storage/policies --output /tmp/temp_storagepolicies.json)
if [[ "${response}" -ne 200 ]] ; then
  echo "Error: Could not fetch storage policy. Please validate!!"
  exit 1
fi

export TKGStoragePolicy=$(jq -r --arg K8S_STORAGE_POLICY "$K8S_STORAGE_POLICY" '.[]| select(.name == $K8S_STORAGE_POLICY)|.policy' /tmp/temp_storagepolicies.json)
#export TKGStoragePolicy=$(jq -r --arg K8S_STORAGE_POLICY "$K8S_STORAGE_POLICY" '.[]| select(.name|contains($K8S_STORAGE_POLICY))|.policy' /tmp/temp_storagepolicies.json)
if [ -z "${TKGStoragePolicy}" ]
then
        echo "Error: Could not fetch storage policy - ${K8S_STORAGE_POLICY} . Please validate!!"
        exit 1
fi

################################################
# Get network details from vCenter
###############################################
echo "Searching for Network portgroups  ..."
response=$(curl -ks --write-out "%{http_code}" -X GET  -H "${HEADER_SESSIONID}" https://${VCENTER_HOSTNAME}/api/vcenter/network --output /tmp/temp_networkportgroups.json)
if [[ "${response}" -ne 200 ]] ; then
  echo "Error: Could not fetch network details. Please validate!!"
  exit 1
fi

export TKGMgmtNetwork=$(jq -r --arg K8S_MGMT_PORTGROUP "$K8S_MGMT_PORTGROUP" '.[]| select(.name == $K8S_MGMT_PORTGROUP)|.network' /tmp/temp_networkportgroups.json)
export TKGWorkload0Network=$(jq -r --arg K8S_WKD0_PORTGROUP "$K8S_WKD0_PORTGROUP" '.[]| select(.name == $K8S_WKD0_PORTGROUP)|.network' /tmp/temp_networkportgroups.json)
export TKGWorkload1Network=$(jq -r --arg K8S_WKD1_PORTGROUP "$K8S_WKD1_PORTGROUP" '.[]| select(.name == $K8S_WKD1_PORTGROUP)|.network' /tmp/temp_networkportgroups.json)
if [ -z "${TKGMgmtNetwork}" ]
then
        echo "Error: Could not fetch portgroup - ${K8S_MGMT_PORTGROUP} . Please validate!!"
        exit 1
fi
if [ -z "${TKGWorkload0Network}" ]
then
        echo "Error: Could not fetch portgroup - ${K8S_WKD0_PORTGROUP} . Please validate!!"
        exit 1
fi
if [ -z "${TKGWorkload1Network}" ]
then
        echo "Error: Could not fetch portgroup - ${K8S_WKD0_PORTGROUP} . Please validate!!"
        exit 1
fi

################################################
# Get cluster details from vCenter
###############################################
envsubst < VcenterNamespaceManagementClustersInfo.json > temp_final.json

echo "Enabling WCP on cluster ${TKGClusterID} ..."
curl -ks -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "@temp_final.json" https://${VCENTER_HOSTNAME}/api/vcenter/namespace-management/clusters/${TKGClusterID}?action=enable

rm -f /tmp/temp_*.*
