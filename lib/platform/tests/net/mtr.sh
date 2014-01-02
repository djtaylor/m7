#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Network Test - MTR
#
# !arg0		'Test plan ID'
# !arg1		'Test definition ID'
# !arg2 	'Test plan category'
# !arg3		'Number of packets'
# !arg4     'Test category type'
MTR_TEST_ARGS=(\
"{TEST_PLAN_ID}"
"{TEST_DEF_ID}"
"{TEST_CAT}"
"{TEST_MTR_COUNT}"
"{TEST_CAT_TYPE}"
"{TEST_PLAN}")

# Set the base directory from the plan ID, test ID, and thread number
MTR_TEST_BASE=~/output/${MTR_TEST_ARGS[0]}/local/test-${MTR_TEST_ARGS[1]}
mkdir -p $MTR_TEST_BASE/tmp

# Generate the test lockfile directory and create the test thread lockfile
MTR_TEST_LOCK_DIR=~/lock/${MTR_TEST_ARGS[0]}/local
MTR_TEST_LOCK="$MTR_TEST_LOCK_DIR/test-${MTR_TEST_ARGS[1]}"
mkdir -p $MTR_TEST_LOCK_DIR
touch $MTR_TEST_LOCK

# Set the test output log file
MTR_TEST_LOG="$MTR_TEST_BASE/output.log"

# Start the test loop
echo "######################################################################" | tee $MTR_TEST_LOG
echo "INITIALIZING TEST:   '${MTR_TEST_ARGS[2]}':'${MTR_TEST_ARGS[4]}'" | tee -a $MTR_TEST_LOG
echo "> Test Packet Count: '${MTR_TEST_ARGS[3]}'" | tee -a $MTR_TEST_LOG
echo "> Test Log File:     '$MTR_TEST_LOG'" | tee -a $MTR_TEST_LOG
echo "######################################################################" | tee -a $MTR_TEST_LOG

# Build an array of all cluster nodes except the localhost
MTR_NODES_ARRAY=( `sqlite3 ~/db/cluster.db "SELECT Name FROM M7_Nodes WHERE Name!='$(hostname -s)';"` )

# Build an array of satellite hosts
MTR_SHOSTS_ARRAY=( `echo "cat //plan/params/hosts/host/@name" | xmllint --shell "${MTR_TEST_ARGS[5]}" | grep "name" | sed "s/^.*name=\"\([^\"]*\)\".*$/\1/g"` )

# Check if we are skipping inter-cluster tests
MTR_SKIP_CLUSTER="$(xml "parse" "${MTR_TEST_ARGS[5]}" "params/skipcluster/text()")"

# MTR to every node in the cluster if not skipping inter-cluster tests
if [ "$MTR_SKIP_CLUSTER" = "no" ]; then
	for MTR_NODE in "${MTR_NODES_ARRAY[@]}"
	do
		
		# Get the node IP address
		MTR_NODE_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Name='$MTR_NODE';")"
		
		# Define the node MTR log file
		MTR_NODE_LOG="$MTR_TEST_BASE/tmp/$MTR_NODE.log" && touch $MTR_NODE_LOG
		
		# Run the MTR command
		echo "RUNNING MTR TEST('$MTR_NODE:$MTR_NODE_IP_ADDR')" | tee -a $MTR_TEST_LOG
		echo "Log: '$MTR_NODE_LOG'" | tee -a $MTR_TEST_LOG
		/usr/bin/sudo /usr/sbin/mtr -n --report --report-wide --report-cycles ${MTR_TEST_ARGS[3]} $MTR_NODE_IP_ADDR >> $MTR_NODE_LOG && MTR_NODE_EXIT_CODE="$(echo $?)"
		echo "Exit Code: '$MTR_NODE_EXIT_CODE'" | tee -a $MTR_TEST_LOG
		echo "EXIT:'$MTR_NODE_EXIT_CODE'" >> $MTR_NODE_LOG
	done
fi

# If any satellite hosts are defined
if [ ${#MTR_SHOSTS_ARRAY[@]} -gt 0 ]; then
	
	# Ping to every satellite node
	for MTR_SHOST in "${MTR_SHOSTS_ARRAY[@]}"
	do
		
		# Get the node IP address
		MTR_SHOST_IP_ADDR="$(xml "parse" "${MTR_TEST_ARGS[5]}" "params/hosts/host[@name='$MTR_SHOST']/text()")"
		
		# Define the node MTR log file
		MTR_SHOST_LOG="$MTR_TEST_BASE/tmp/$MTR_SHOST.log"
		
		# Run the MTR command
		echo "RUNNING MTR TEST('$MTR_SHOST:$MTR_SHOST_IP_ADDR')" | tee -a $MTR_TEST_LOG
		echo "Log: '$MTR_SHOST_LOG'" | tee -a $MTR_TEST_LOG
		echo "RUN:'$(date +"%Y-%m-%d %H:%M:%S")'" > $MTR_SHOST_LOG
		/usr/bin/sudo /usr/sbin/mtr -n --report --report-wide --report-cycles ${MTR_TEST_ARGS[3]} $MTR_SHOST_IP_ADDR >> $MTR_SHOST_LOG && MTR_SHOST_EXIT_CODE="$(echo $?)"
		echo "Exit Code: '$MTR_SHOST_EXIT_CODE'" | tee -a $MTR_TEST_LOG
		echo "EXIT:'$MTR_SHOST_EXIT_CODE'" >> $MTR_SHOST_LOG	
	done
fi
echo "######################################################################" | tee -a $MTR_TEST_LOG
echo "TEST COMPLETED" | tee -a $MTR_TEST_LOG
echo "######################################################################" | tee -a $MTR_TEST_LOG
	
# Remove the lock file
rm -f $MTR_TEST_LOCK

# Self destruct the script
rm -f /tmp/${MTR_TEST_ARGS[0]}.${MTR_TEST_ARGS[2]}.test-${MTR_TEST_ARGS[1]}.sh