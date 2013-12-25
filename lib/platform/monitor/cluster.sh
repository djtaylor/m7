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

# Compress the results directory
cd ~/results && tar czf $CM_TARGET_ID-results.tar.gz $CM_TARGET_ID

# Define the email subject and body
CM_EMAIL_SUBJECT="M7 Test Complete - '$CM_TARGET_ID'"
CM_EMAIL_BODY="Testing has been completed for M7 test '$CM_TARGET_ID'. See the attached XML file to review the test plan, and the attached archive file to view the results from each M7 node."

# Copy the results into the HTML directory
cp -a ~/results/$CM_TARGET_ID ~/html/results/.

# Self destruct the script
rm -f /tmp/$CM_TARGET_ID.cluster.monitor.sh