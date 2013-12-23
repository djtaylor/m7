#!/bin/bash

# GitHub->Local Repository Sync
#
# This library manages synchronization between the upstream GitHub repository
# and the local server that is running the sync.

git_sync() {
	
	# Change to a temporary working directory
	mkdir /tmp/m7_git_sync
	cd /tmp/m7_git_sync
	
	# Clone the Git repository
	git clone https://github.com/djtaylor/m7.git
	
	# Rsync the directories
	rsync -a -v /tmp/m7_git_sync/m7/ /opt/vpls/m7/.
	
	# Leave the working directory and delete it
	cd && rm -rf /tmp/m7_git_sync
	
}

readonly -f git_sync