#!/usr/bin/env bash

##############################################################################
#
# This script is a dynamic inventory for ansible playbooks which intend to
# manage OpenShift cluster with Arbiter zone
#
# Created on : 26 MAy, 2021
# By : Avi Liani <alayani@redhat.com>
#
##############################################################################

INV_DIR="inventory"
INV_FILE="${INV_DIR}/inventory"

OC=`which oc 2>/dev/null`
if [[ ! $? -eq 0 ]] ; then
	# "oc is not installed, Exiting !!!"
	exit
fi

function get_nodes () 
{
	# This function return list of nodes with a specific selector
	# Args:
	#  Selectore (str) : the selectore to look for
	# Returns:
	#  list : list of nodes
	SEL=$1
	results=`${OC} get node -l ${SEL} | grep -v NAME | awk '{print $1}'`
	echo $results
}

function get_node_by_type ()
{
	# This function return list of specific node type (master/worker)
	# Args:
	#  Type (str) : the node type to look for
	# Returns:
	#  list : list of nodes
	TYPE=$1
	results=$(get_nodes "node-role.kubernetes.io/${TYPE}")
	echo $results
}

function get_node_by_zone ()
{
	# This function return list of nodes in specific zone (A/B/C) 
	# Args:
	#  Zone (str) : the zone to look for
	# Returns:
	#  list : list of nodes
	zone=$1
	results=$(get_nodes "topology.beta.kubernetes.io/zone=${zone}")
	echo $results
}

function get_node_ip ()
{
	# This function return the node External IP
	# Args:
	#  Node (str) : the node name
	# Returns:
	#  string : The node IP
	NODE=$1
	results=`${OC} get node ${NODE} -o jsonpath={.status.addresses[0].address}`
	echo $results
}

# Creating the Inventory directory and static file
if [[ ! -d ${INV_DIR} ]] ; then
       mkdir -p ${INV_DIR}
fi

> ${INV_FILE}

# Setting up localhost as control host
echo "[control]" >> ${INV_FILE}
echo localhost >> ${INV_FILE}
echo >> ${INV_FILE}

# Getting list of ALL nodes
NODES=`$OC get node 2>/dev/null`
if [[ ! $? -eq 0 ]] ; then
	# "OpenShift cluster is not accessable, Exiting !!!"
	exit
fi

# Getting list of 'worker' nodes
WORKER_LIST=($(get_node_by_type worker))

# Getting list of 'master' nodes
MASTER_LIST=($(get_node_by_type master))

# Creation host group for each type of nodes
for ntype in master worker ; do
	echo "[${ntype}s]" >> ${INV_FILE}
	list_name="${ntype}_list"
	list_name=${list_name^^}
	list=($list_name[@])
	for host in ${!list} ; do
		IP=$(get_node_ip ${host})
		echo "${host} ansible_host=${IP}" >> ${INV_FILE}
	done
	echo >> ${INV_FILE}
done

# Creating host group for each zone in the cluster
for zone in A B C ; do
	zone_name=`echo "$zone" | tr '[:upper:]' '[:lower:]'` 
	echo  "[zone${zone_name}]" >> ${INV_FILE}  
	FOUND=0
	for host in $(get_node_by_zone Zone-${zone}) ; do
		echo "${host}" >> ${INV_FILE}
		FOUND=1
	done
	echo >> ${INV_FILE}

	if [[ ! $FOUND ]] ; then
		if [[ $zone == "A" ]] ; then
			((WIND=0))
			((WEND=2))
			((MIND=0))
		elif [[ $zone == "B" ]] ; then
			((WIND=2))
			((WEND=4))
			((MIND=1))
		elif [[ $zone == "C" ]] ; then
			((WIND=-1))
			((WEND=-2))
			((MIND=2))
		fi
		
		if [[ $WIND -ge 0 ]] ; then
			for host in ${WOKER_LIST[@]:$WIND:$WEND} ${MASTER_LIST[$MIND]} ; do 
				echo "${host}" >> ${INV_FILE}
			done
		else
			echo "${MASTER_LIST[$MIND]}" >> ${INV_FILE}
		fi
	fi
	echo >> ${INV_FILE}

done

# Creation host group for all nodes
echo "[nodes:children]" >> ${INV_FILE}
echo "workers" >> ${INV_FILE}
echo "masters" >> ${INV_FILE}
echo >> ${INV_FILE}

ansible-inventory -i ${INV_FILE} $*

