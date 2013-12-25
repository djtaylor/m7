#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Plan ID / Plan File
CM_TARGET_ID="$1"
CM_SOURCE_PLAN="$2"

while :
do
	
	# If all local and worker local files have been cleared
	if [ -z "$(ls -A ~/lock/$CM_TARGET_ID/local)" ] \
	&& [ -z "$(ls -A ~/lock/$CM_TARGET_ID/worker)" ]; then
		break
	else
		sleep 2
	fi
done

# Get the notification email
CM_EMAIL="$(xml "parse" "$CM_SOURCE_PLAN" "email/text()")"

# 1.) Aggregated test results into a directory
# 2.) Compress the directory
# 3.) Generate email body and subject
# 4.) Send email to notification address

# Self destruct the script
rm -f /tmp/$CM_TARGET_ID.cluster.monitor.sh