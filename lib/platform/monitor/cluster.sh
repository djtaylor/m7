#!/bin/bash

# Load the library index
source ~/lib/index.sh

# Plan ID / Plan File
CM_TARGET_ID="$1"
CM_SOURCE_PLAN="$2"

# Get the test type
CM_TEST_TYPE="$(xml "parse" "$CM_SOURCE_PLAN" "params/category/text()")"

# Wait until the local and worker lock files have been cleared
while :
do
	if [ -z "$(ls -A ~/lock/$CM_TARGET_ID/local)" ] \
	&& [ -z "$(ls -A ~/lock/$CM_TARGET_ID/worker)" ]; then
		break
	else
		sleep 2
	fi
done

# Copy the results and plan into the HTML directory
cp -a ~/results/$CM_TARGET_ID ~/html/results/.
cp $CM_SOURCE_PLAN ~/html/results/$CM_TARGET_ID/plan.xml

# Load the results into the database
case "$CM_TEST_TYPE" in
	"net")
		/usr/bin/perl ~/lib/perl/net/xml_to_db.pl $CM_TARGET_ID
	"web")
		:
esac

# Clean up the output and lock directories
rm -rf ~/output/$CM_TARGET_ID
rm -rf ~/lock/$CM_TARGET_ID

# Self destruct the script
rm -f /tmp/$CM_TARGET_ID.cluster.monitor.sh