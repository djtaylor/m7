#!/bin/bash

# M7 Test Distribution Library
#
# The following script is run prior to local test execution on the director node
# only, and starts the testing process on any available worker nodes.

test_dist() {
	
	# Test Distribution Arguments
	#
	# arg1 -> Test plan file
	TEST_DIST_ARGS=( "$@" )
	
	# Only run from a director node
	if [ ! -z "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Type='director' AND Name='$(hostname -s)';")" ]; then
		
		# Check if any worker nodes are indexed
		TEST_DIST_WORKERS=( `sqlite3 ~/db/cluster.db "SELECT Id FROM M7_Nodes WHERE Type='worker';"` )
		if [ ${#TEST_DIST_WORKERS[@]} -gt 0 ]; then
		        
			# If no test plan supplied
			if [ ! -f "${TEST_DIST_ARGS[0]}" ]; then
				log "error" "No test plan (arg1) supplied..."
				exit 1
			else
			
				# Get the test plan ID number and generate the worker lock/output directory
				TEST_DIST_ID="$(xml "parse" "${TEST_DIST_ARGS[0]}" "id/text()")"
				mkdir -p ~/lock/$TEST_DIST_ID/worker
				mkdir -p ~/output/$TEST_DIST_ID/worker
			
				# Run the test on each worker node and generate a lock file
				for TEST_DIST_WORKER_ID in "${TEST_DIST_WORKERS[@]}"
		        do
		        	
		        	# Get the worker node user, ssh port, and IP address
					TEST_DIST_WORKER_USER="$(sqlite3 ~/db/cluster.db "SELECT User FROM M7_Nodes WHERE Id='$TEST_DIST_WORKER_ID';")"
		        	TEST_DIST_WORKER_SSH_PORT="$(sqlite3 ~/db/cluster.db "SELECT SSHPort FROM M7_Nodes WHERE Id='$TEST_DIST_WORKER_ID';")"
		        	TEST_DIST_WORKER_IP_ADDR="$(sqlite3 ~/db/cluster.db "SELECT IPAddr FROM M7_Nodes WHERE Id='$TEST_DIST_WORKER_ID';")"
		        	
		        	# Create the test plans directory
					ssh -i $M7KEY -p $TEST_DIST_WORKER_SSH_PORT -o StrictHostKeyChecking=no $TEST_DIST_WORKER_USER@$TEST_DIST_WORKER_IP_ADDR mkdir -p ~/plans
					if [ "$?" != "0" ]; then
						log "error" "Failed to generate test plans directory on worker node '$TEST_DIST_WORKER_ID'..."
					else
						log "info" "Generating test plan directory on worker node '$TEST_DIST_WORKER_ID'..."
					
						# Copy the test plan to the worker node
						scp -i $M7KEY -P $TEST_DIST_WORKER_SSH_PORT -o StrictHostKeyChecking=no ${TEST_DIST_ARGS[0]} $TEST_DIST_WORKER_USER@$TEST_DIST_WORKER_IP_ADDR:~/plans/.
						if [ "$?" != "0" ]; then
							log "error" "Failed to copy test plan to worker node '$TEST_DIST_WORKER_ID'..."	
						else
							log "info" "Copying test plan to worker node '$TEST_DIST_WORKER_ID'..."
						
							# Execute the test plan on the worker node
							ssh -i $M7KEY -p $TEST_DIST_WORKER_SSH_PORT -o StrictHostKeyChecking=no $TEST_DIST_WORKER_USER@$TEST_DIST_WORKER_IP_ADDR 'bash -c -l "m7 run '${TEST_DIST_ARGS[0]}'"'
							if [ "$?" != "0" ]; then
								log "error" "Failed to launch test process on worker node '$TEST_WORKER_ID'..."
							else
								log "info" "Executing test plan on worker node '$TEST_DIST_WORKER_ID'..."
								
								# Create the worker lock file
								touch ~/lock/$TEST_DIST_ID/worker/$TEST_DIST_WORKER_ID && echo "$(date +"%H:%M:%S")" > ~/lock/$TEST_DIST_ID/worker/$TEST_DIST_WORKER_ID
								
								# Generate the worker monitor script
								TEST_DIST_WORKER_MONITOR="/tmp/$TEST_DIST_ID.workers.sh"
								cat ~/lib/platform/workers.sh > $TEST_DIST_WORKER_MONITOR && chmod +x $TEST_DIST_WORKER_MONITOR
							fi
						fi
					fi
		        done
		        
		        # Launch the worker monitor script
				nohup sh $TEST_DIST_WORKER_MONITOR "$TEST_DIST_ID" >/dev/null 2>&1 &
		        
			fi
		fi
	fi
	
}

readonly -f test_dist