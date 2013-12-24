#!/bin/bash

# M7 Library Index
#
# The following script is run first when running the M7 executable to load
# any shared libraries required by the platform.

# Platform Variables
M7LOG_ERROR=~/log/error.log
M7LOG_MAIN=~/log/main.log
M7DB=~/db/cluster.db
M7KEY=~/.ssh/m7.key

# Output Variables
SUCCESS="\e[1;32mSUCCESS\e[0m"
FAILED="\e[1;31mFAILED\e[0m"

# Load all the library files in $M7ROOT/lib/core
for LIB_FILE in $(find ~/lib/core -type f)
do
	source $LIB_FILE
done