#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Network Test - Ping
#
# !arg0		'Test plan ID'
# !arg1		'Test definition ID'
# !arg2 	'Test plan category'
# !arg3		'Number of pings'
# !arg4     'Test category type'
PING_TEST_ARGS=(\
"{TEST_PLAN_ID}"
"{TEST_DEF_ID}"
"{TEST_CAT}"
"{TEST_PING_COUNT}"
"{TEST_CAT_TYPE}"
"{TEST_PLAN}")

# Set the base directory from the plan ID, test ID, and thread number
PING_TEST_BASE=~/output/${PING_TEST_ARGS[0]}/local/test-${PING_TEST_ARGS[1]}
mkdir -p $PING_TEST_BASE/tmp

# Generate the test lockfile directory and create the test thread lockfile
PING_TEST_LOCK_DIR=~/lock/${PING_TEST_ARGS[0]}/local
PING_TEST_LOCK="$PING_TEST_LOCK_DIR/test-${PING_TEST_ARGS[1]}"
mkdir -p $PING_TEST_LOCK_DIR
touch $PING_TEST_LOCK

# Set the test output log file
PING_TEST_LOG="$PING_TEST_BASE/output.log"

# Start the test loop
echo "######################################################################" | tee $PING_TEST_LOG
echo "INITIALIZING TEST: '${PING_TEST_ARGS[2]}':'${PING_TEST_ARGS[4]}'" | tee -a $PING_TEST_LOG
echo "> Test Ping Count: '${PING_TEST_ARGS[3]}'" | tee -a $PING_TEST_LOG
echo "> Test Log File:   '$PING_TEST_LOG'" | tee -a $PING_TEST_LOG
echo "######################################################################" | tee -a $PING_TEST_LOG

# Build an array of all cluster nodes except the localhost
PING_NODES_ARRAY=( `sqlite3 ~/db/cluster.db "SELECT Name FROM M7_Nodes WHERE Name!='$(hostname -s)';"` )

# Build an array of supplementary hosts
PING_SHOSTS_ARRAY=( `echo "cat //plan/params/hosts/host/@name" | xmllint --shell "${PING_TEST_ARGS[5]}" | grep "name" | sed "s/^.*name=\"\([^\"]*\)\".*$/\1/g"` )

# Ping every node in the cluster
for PING_NODE in "${PING_NODES_ARRAY[@]}"
do
	
	# Get the node IP address
	PING_NODE_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Name='$PING_NODE';")"
	
	# Define the node ping log file
	PING_NODE_LOG="$PING_TEST_BASE/tmp/$PING_NODE.log" && touch $PING_NODE_LOG
	
	# Run the ping command
	echo "RUNNING PING TEST('$PING_NODE:$PING_NODE_IP_ADDR')" | tee -a $PING_TEST_LOG
	echo "Log: '$PING_NODE_LOG'" | tee -a $PING_TEST_LOG
	ping -c ${PING_TEST_ARGS[3]} $PING_NODE_IP_ADDR > $PING_NODE_LOG && PING_NODE_EXIT_CODE="$(echo $?)"
	echo "Exit Code: '$PING_NODE_EXIT_CODE'" | tee -a $PING_TEST_LOG
	echo "EXIT:'$PING_NODE_EXIT_CODE'" >> $PING_NODE_LOG
done

# If any supplementary hosts are defined
if [ ${#PING_SHOSTS_ARRAY[@]} -gt 0 ]; then
	
	# Ping to every supplementary node
	for PING_SHOST in "${PING_SHOSTS_ARRAY[@]}"
	do
		
		# Get the node IP address
		PING_SHOST_IP_ADDR="$(xml "parse" "${PING_TEST_ARGS[5]}" "params/hosts/host[@name='$PING_SHOST']/text()")"
		
		# Define the node ping log file
		PING_SHOST_LOG="$PING_TEST_BASE/tmp/$PING_SHOST.log"
		
		# Run the ping command
		echo "RUNNING PING TEST('$PING_SHOST:$PING_SHOST_IP_ADDR')" | tee -a $PING_TEST_LOG
		echo "Log: '$PING_SHOST_LOG'" | tee -a $PING_TEST_LOG
		ping -c ${PING_TEST_ARGS[3]} $PING_SHOST_IP_ADDR > $PING_SHOST_LOG && PING_SHOST_EXIT_CODE="$(echo $?)"
		echo "Exit Code: '$PING_SHOST_EXIT_CODE'" | tee -a $PING_TEST_LOG
		echo "EXIT:'$PING_SHOST_EXIT_CODE'" >> $PING_SHOST_LOG	
	done
fi
echo "######################################################################" | tee -a $PING_TEST_LOG
echo "TEST COMPLETED" | tee -a $PING_TEST_LOG
echo "######################################################################" | tee -a $PING_TEST_LOG
	
# Remove the lock file
rm -f $PING_TEST_LOCK

# Self destruct the script
rm -f /tmp/${PING_TEST_ARGS[0]}.${PING_TEST_ARGS[2]}.test-${PING_TEST_ARGS[1]}.sh