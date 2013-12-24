#!/bin/bash

# M7 Test Execution Library
#
# This library is used to process the XML test plan and run the approprate
# test platform script.

test_exec() {
	
	# Test Execution Arguments
	#
	# arg1 -> Test plan file
	TEST_EXEC_ARGS=( "$@" )
	
	# If no test plan supplied
	if [ ! -f "${TEST_EXEC_ARGS[0]}" ]; then
		log "error" "No test plan (arg1) supplied..."
		exit 1
	fi
	
	regex_str() {
		INPUT_STR="$1"
	    REGEX_META1="${INPUT_STR//\//\\/}"
	    REGEX_META2="${REGEX_META1//\^/\\^}"
	    REGEX_META3="${REGEX_META2//\./\\.}"
	    REGEX_META4="${REGEX_META3//\*/\\*}"
	    REGEX_META5="${REGEX_META4//\$/\\$}"
	    REGEX_META6="${REGEX_META5//\+/\\+}"
		REGEX_META7="${REGEX_META6//\[/\\[}"
		REGEX_META8="${REGEX_META7//\]/\\]}"
	    REGEX_META9="${REGEX_META8//\</\\<}"
	    REGEX_META10="${REGEX_META9//\>/\\>}"
	    REGEX_META11="${REGEX_META10//\@/\\@}"
	    REGEX_STR="$REGEX_META11"
	    echo "$REGEX_STR"	
	}
	
	# Get the test plan ID and category
	TEST_EXEC_ID="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "id/text()")"
	TEST_EXEC_CAT="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/category/text()")"
	
	# Test category processor
	case "$TEST_EXEC_CAT" in
		
		"net")
		
			# Get each test definition by ID number
			TEST_EXEC_NET_TESTS=( `echo "cat //plan/params/test/@id" | xmllint --shell "${TEST_EXEC_ARGS[0]}" | grep "id" | sed "s/id=\"\([0-9]*\)\"/\1/g"` )
		
			# Process each unique test definition
			for TEST_EXEC_NET_TEST_ID in "${TEST_EXEC_NET_TESTS[@]}"
			do
				
				# Get the test type and launch the test
				TEST_EXEC_NET_TYPE="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_EXEC_NET_TEST_ID']/type/text()")"
				case "$TEST_EXEC_NET_TYPE" in
					
					"ping")
					
						# Define the thread script
						TEST_EXEC_NET_PING_SCRIPT="/tmp/$TEST_EXEC_ID.$TEST_EXEC_CAT.test-$TEST_EXEC_NET_TEST_ID.sh"
						
						# Create the thread script
						cat ~/lib/platform/tests/$TEST_EXEC_CAT/$TEST_EXEC_NET_TYPE.sh > $TEST_EXEC_NET_PING_SCRIPT; chmod +x $TEST_EXEC_NET_PING_SCRIPT
						
						# Get the ping count
						TEST_EXEC_NET_PING_COUNT="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_EXEC_NET_TEST_ID']/count/text()")"
						
						# Update the arguments in the script
						sed -i "s/{TEST_PLAN_ID}/$TEST_EXEC_ID/g" $TEST_EXEC_NET_PING_SCRIPT
						sed -i "s/{TEST_DEF_ID}/$TEST_EXEC_NET_TEST_ID/g" $TEST_EXEC_NET_PING_SCRIPT
						sed -i "s/{TEST_CAT}/$TEST_EXEC_CAT/g" $TEST_EXEC_NET_PING_SCRIPT
						sed -i "s/{TEST_PING_COUNT}/$TEST_EXEC_NET_PING_COUNT/g" $TEST_EXEC_NET_PING_SCRIPT
						sed -i "s/{TEST_CAT_TYPE}/$TEST_EXEC_NET_TYPE/g" $TEST_EXEC_NET_PING_SCRIPT
						
						# Launch the thread
						nohup sh $TEST_EXEC_NET_PING_SCRIPT >/dev/null 2>&1 &
						;;
						
					"traceroute")
						:
						;;
					
					"mtr")
						:
						;;
						
					*)
						log "error" "Invalid test type for category:['$TEST_EXEC_CAT']: '$TEST_EXEC_NET_TYPE'"
						
				esac
			done
			
			# Generate the test monitor script
			TEST_EXEC_MON="/tmp/$TEST_EXEC_ID.local.monitor.sh"
			cat ~/lib/platform/monitor/net.local.sh > $TEST_EXEC_MON && chmod +x $TEST_EXEC_MON
			
			# Launch the test monitor script
			nohup sh $TEST_EXEC_MON "$TEST_EXEC_ID" "${TEST_EXEC_ARGS[0]}" >/dev/null 2>&1 &
			
			# If running from a director node
			if [ ! -z "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Type='director' AND Name='$(hostname -s)';")" ]; then
				
				# Create and launch the cluster monitor script
				TEST_EXEC_CLUSTER_MON="/tmp/$TEST_EXEC_ID.cluster.monitor.sh"
				cat ~/lib/platform/monitor/cluster.sh > $TEST_EXEC_CLUSTER_MON && chmod +x $TEST_EXEC_CLUSTER_MON
				nohup sh $TEST_EXEC_CLUSTER_MON "$TEST_EXEC_ID" "${TEST_EXEC_ARGS[0]}" >/dev/null 2>&1 &
			fi
			;;
		
		"web")
		
			# Get the web test protocol and host
			TEST_EXEC_WEB_PROTO="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/proto/text()")"
			TEST_EXEC_WEB_HOST="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/host/text()")"
			
			# Set the number of test threads
			TEST_EXEC_THREAD_LIMIT="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/threads/text()")"
			
			# Get each test definition by ID number
			TEST_EXEC_WEB_TESTS=( `echo "cat //plan/params/test/@id" | xmllint --shell "${TEST_EXEC_ARGS[0]}" | grep "id" | sed "s/id=\"\([0-9]*\)\"/\1/g"` )
			
			# Process each unique test definition
			for TEST_EXEC_WEB_TEST_ID in "${TEST_EXEC_WEB_TESTS[@]}"
			do
				
				# Get the test type
				TEST_EXEC_WEB_TYPE="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_EXEC_WEB_TEST_ID']/type/text()")"
				
				# Process and run the tests based on type
				case "$TEST_EXEC_WEB_TYPE" in
					
					"single-download")
					
						# Get the file path and samples
						TEST_EXEC_WEB_FPATH="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_EXEC_WEB_TEST_ID']/path/text()")"
						TEST_EXEC_WEB_SAMPLES="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_EXEC_WEB_TEST_ID']/samples/text()")"
					
						# Run based on the number of threads
						TEST_EXEC_THREAD_COUNT="0"
						while [ "$TEST_EXEC_THREAD_LIMIT" -gt "$TEST_EXEC_THREAD_COUNT" ]
						do
							let TEST_EXEC_THREAD_COUNT++
							
							# Define the thread script
							TEST_EXEC_WEB_SD_SCRIPT="/tmp/$TEST_EXEC_ID.$TEST_EXEC_CAT.test-$TEST_EXEC_WEB_TEST_ID.thread-$TEST_EXEC_THREAD_COUNT.sh"
							
							# Create the thread script
							cat ~/lib/platform/tests/$TEST_EXEC_CAT/$TEST_EXEC_WEB_TYPE.sh > $TEST_EXEC_WEB_SD_SCRIPT; chmod +x $TEST_EXEC_WEB_SD_SCRIPT
							
							# Update the arguments in the script
							sed -i "s/{TEST_PLAN_ID}/$TEST_EXEC_ID/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_DEF_ID}/$TEST_EXEC_WEB_TEST_ID/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_CAT}/$TEST_EXEC_CAT/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_THREAD_NUM}/$TEST_EXEC_THREAD_COUNT/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_TARGET_HOST}/$(regex_str "$TEST_EXEC_WEB_HOST")/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_HOST_PROTO}/$TEST_EXEC_WEB_PROTO/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_FILE_PATH}/$(regex_str "$TEST_EXEC_WEB_FPATH")/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_SAMPLES}/$TEST_EXEC_WEB_SAMPLES/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_CAT_TYPE}/$TEST_EXEC_WEB_TYPE/g" $TEST_EXEC_WEB_SD_SCRIPT
							
							# Launch the thread
							nohup sh $TEST_EXEC_WEB_SD_SCRIPT >/dev/null 2>&1 &
						done
						;;
						
					"multi-download")
					
						# Build a string of all files
						TEST_EXEC_MULTI_WORKSPACE="/tmp/$TEST_EXEC_ID.$TEST_EXEC_WEB_TEST_ID.multi"
						echo "cat //plan/params/test[@id='$TEST_EXEC_WEB_TEST_ID']/paths/path" | xmllint --shell ${TEST_EXEC_ARGS[0]} > $TEST_EXEC_MULTI_WORKSPACE
						declare TEST_EXEC_MULTI_STRING
						while read TEST_EXEC_MULTI_PATH
						do
							if [[ $TEST_EXEC_MULTI_PATH =~ ^.*path.*$ ]]; then
								if [ -z "$TEST_EXEC_MULTI_STRING" ]; then
									TEST_EXEC_MULTI_STRING="$(echo $TEST_EXEC_MULTI_PATH | sed "s/^<path>\([^<]*\)<\/path>$/\1/g");"
								else
									TEST_EXEC_MULTI_STRING+=";$(echo $TEST_EXEC_MULTI_PATH | sed "s/^<path>\([^<]*\)<\/path>$/\1/g")"
								fi
							fi
						done < $TEST_EXEC_MULTI_WORKSPACE
					
						# Get the number of samples
						TEST_EXEC_WEB_SAMPLES="$(xml "parse" "${TEST_EXEC_ARGS[0]}" "params/test[@id='$TEST_EXEC_WEB_TEST_ID']/samples/text()")"
					
						# Run based on the number of threads
						TEST_EXEC_THREAD_COUNT="0"
						while [ "$TEST_EXEC_THREAD_LIMIT" -gt "$TEST_EXEC_THREAD_COUNT" ]
						do
							let TEST_EXEC_THREAD_COUNT++
							
							# Define the thread script
							TEST_EXEC_WEB_SD_SCRIPT="/tmp/$TEST_EXEC_ID.$TEST_EXEC_CAT.test-$TEST_EXEC_WEB_TEST_ID.thread-$TEST_EXEC_THREAD_COUNT.sh"
							
							# Create the thread script
							cat ~/lib/platform/tests/$TEST_EXEC_CAT/$TEST_EXEC_WEB_TYPE.sh > $TEST_EXEC_WEB_SD_SCRIPT; chmod +x $TEST_EXEC_WEB_SD_SCRIPT
							
							# Update the arguments in the script
							sed -i "s/{TEST_PLAN_ID}/$TEST_EXEC_ID/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_DEF_ID}/$TEST_EXEC_WEB_TEST_ID/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_CAT}/$TEST_EXEC_CAT/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_THREAD_NUM}/$TEST_EXEC_THREAD_COUNT/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_TARGET_HOST}/$(regex_str "$TEST_EXEC_WEB_HOST")/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_HOST_PROTO}/$TEST_EXEC_WEB_PROTO/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_FILE_PATH}/$(regex_str "$TEST_EXEC_MULTI_STRING")/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_SAMPLES}/$TEST_EXEC_WEB_SAMPLES/g" $TEST_EXEC_WEB_SD_SCRIPT
							sed -i "s/{TEST_CAT_TYPE}/$TEST_EXEC_WEB_TYPE/g" $TEST_EXEC_WEB_SD_SCRIPT
							
							# Launch the thread
							nohup sh $TEST_EXEC_WEB_SD_SCRIPT >/dev/null 2>&1 &
						done
						;;
						
					*)
						log "error" "Invalid test type for category:['$TEST_EXEC_CAT']: '$TEST_EXEC_WEB_TYPE'"
					
				esac
			done
			
			# Generate the test monitor script
			TEST_EXEC_MON="/tmp/$TEST_EXEC_ID.local.monitor.sh"
			cat ~/lib/platform/monitor/web.local.sh > $TEST_EXEC_MON && chmod +x $TEST_EXEC_MON
			
			# Launch the test monitor script
			nohup sh $TEST_EXEC_MON "$TEST_EXEC_ID" "${TEST_EXEC_ARGS[0]}" >/dev/null 2>&1 &
			
			# If running from a director node
			if [ ! -z "$(sqlite3 ~/db/cluster.db "SELECT * FROM M7_Nodes WHERE Type='director' AND Name='$(hostname -s)';")" ]; then
				
				# Create and launch the cluster monitor script
				TEST_EXEC_CLUSTER_MON="/tmp/$TEST_EXEC_ID.cluster.monitor.sh"
				cat ~/lib/platform/monitor/cluster.sh > $TEST_EXEC_CLUSTER_MON && chmod +x $TEST_EXEC_CLUSTER_MON
				nohup sh $TEST_EXEC_CLUSTER_MON "$TEST_EXEC_ID" "${TEST_EXEC_ARGS[0]}" >/dev/null 2>&1 &
			fi
			;;
			
		*)
			log "error" "Invalid test category found in plan: '${TEST_EXEC_ARGS[0]}'"
		
	esac
	
}

readonly -f test_exec