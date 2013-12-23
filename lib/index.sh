#!/bin/bash

# M7 Library Index
#
# The following script is run first when running the M7 executable to load
# any shared libraries required by the platform.

# Define core platform variables
M7LOG_ERROR=~/log/error.log
M7LOG_MAIN=~/log/main.log
M7DB=~/db/cluster.db
M7KEY=~/.ssh/m7.key

# Load all the library files in $M7ROOT/lib/core
for LIB_FILE in $(find ~/lib/core -type f)
do
	source $LIB_FILE
done