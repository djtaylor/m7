#!/bin/bash

# Network Test - Ping
#
# !arg0		'Test plan ID'
# !arg1		'Test definition ID'
# !arg2 	'Test plan category'
# !arg4     'Test category type'
TROUTE_TEST_ARGS=(\
"{TEST_PLAN_ID}"
"{TEST_DEF_ID}"
"{TEST_CAT}"
"{TEST_CAT_TYPE}")

# Set the base directory from the plan ID, test ID
TROUTE_TEST_BASE=~/output/${TROUTE_TEST_ARGS[0]}/local/test-${TROUTE_TEST_ARGS[1]}
mkdir -p $TROUTE_TEST_BASE/tmp

# Generate the test lockfile directory and create the test lockfile
TROUTE_TEST_LOCK_DIR=~/lock/${TROUTE_TEST_ARGS[0]}/local
TROUTE_TEST_LOCK="$TROUTE_TEST_LOCK_DIR/test-${TROUTE_TEST_ARGS[1]}"
mkdir -p $TROUTE_TEST_LOCK_DIR
touch $TROUTE_TEST_LOCK

# Set the test output log file
TROUTE_TEST_LOG="$TROUTE_TEST_BASE/output.log"

# Start the test loop
echo "######################################################################" | tee $TROUTE_TEST_LOG
echo "INITIALIZING TEST: '${TROUTE_TEST_ARGS[2]}':'${TROUTE_TEST_ARGS[3]}'" | tee -a $TROUTE_TEST_LOG
echo "> Test Log File:    '$TROUTE_TEST_LOG'" | tee -a $TROUTE_TEST_LOG
echo "######################################################################" | tee -a $TROUTE_TEST_LOG

# Build an array of all cluster nodes except the localhost
TROUTE_NODES_ARRAY=( `sqlite3 ~/db/cluster.db "SELECT Name FROM M7_Nodes WHERE Name!='$(hostname -s)';"` )

# Traceroute to every node in the cluster
for TROUTE_NODE in "${TROUTE_NODES_ARRAY[@]}"
do
	
	# Get the node IP address
	TROUTE_NODE_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Name='$TROUTE_NODE';")"
	
	# Define the node traceroute log file
	TROUTE_NODE_LOG="$TROUTE_TEST_BASE/tmp/$TROUTE_NODE.log" && touch $TROUTE_NODE_LOG
	
	# Run the ping command
	echo "RUNNING TRACEROUTE TEST('$TROUTE_NODE:$TROUTE_NODE_IP_ADDR')" | tee -a $TROUTE_TEST_LOG
	echo "Log: '$TROUTE_NODE_LOG'" | tee -a $TROUTE_TEST_LOG
	traceroute -n $TROUTE_NODE_IP_ADDR > $TROUTE_NODE_LOG && TROUTE_NODE_EXIT_CODE="$(echo $?)"
	echo "Exit Code: '$TROUTE_NODE_EXIT_CODE'" | tee -a $TROUTE_TEST_LOG
	echo "EXIT:'$TROUTE_NODE_EXIT_CODE'" >> $TROUTE_NODE_LOG
done
echo "######################################################################" | tee -a $TROUTE_TEST_LOG
echo "TEST COMPLETED" | tee -a $TROUTE_TEST_LOG
echo "######################################################################" | tee -a $TROUTE_TEST_LOG
	
# Remove the lock file
rm -f $TROUTE_TEST_LOCK

# Self destruct the script
rm -f /tmp/${TROUTE_TEST_ARGS[0]}.${TROUTE_TEST_ARGS[2]}.test-${TROUTE_TEST_ARGS[1]}.sh