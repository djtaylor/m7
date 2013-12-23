#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Target test ID
TM_TARGET_ID="$1"

while :
do
	
	# If all lock files have been cleared
	if [ -z "$(ls -A ~/lock/$TM_TARGET_ID/worker)" ]; then
		break
	else
		sleep 2
	fi
	
done

# Self destruct this script
rm -f /tmp/$TM_TARGET_ID.workers.sh