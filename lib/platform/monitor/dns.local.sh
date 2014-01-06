#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Target test ID and source plan
DM_TARGET_ID="$1"
DM_SOURCE_PLAN="$2"

# Wait until all the local lock files have been cleared
while :
do
	if [ -z "$(ls -A ~/lock/$DM_TARGET_ID/local)" ]; then
		break
	else
		sleep 2
	fi
done