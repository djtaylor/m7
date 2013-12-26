#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Target test ID
TM_TARGET_ID="$1"

# Wait until the worker lock files have been cleared
while :
do
	if [ -z "$(ls -A ~/lock/$TM_TARGET_ID/worker)" ]; then
		break
	else
		sleep 2
	fi
done

# Self destruct this script
rm -f /tmp/$TM_TARGET_ID.worker.monitor.sh