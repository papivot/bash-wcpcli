# BASH Scripts for WCP interactions
---
* `enable-wcp.sh` - Enable WCP on a AVI based setup

1. Modify the bash script `enable-wcp.sh` by editing the following entries per your env. - 
```
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
```

2. Copy `VcenterNamespaceManagementClustersInfo-70.json` or `VcenterNamespaceManagementClustersInfo-80.json` to `VcenterNamespaceManagementClustersInfo.json` depending on the version of vCenter. 
3. Modify `VcenterNamespaceManagementClustersInfo.json` with the relevent static values. Do not modify the variables within ${}. 
4. Execute `enable-wcp.sh`
---
