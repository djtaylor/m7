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
	
	# Delete the local '.git' directory
	rm -rf ~/.git
	
	# Delete the '.gitignore' files
	rm -f ~/output/.gitignore
	rm -f ~/db/.gitignore
	rm -f ~/log/.gitignore
	rm -f ~/plans/.gitignore
	rm -f ~/lock/.gitignore
	
	# Update folder permissions
	chmod 755 $HOME
	find $HOME -type d -exec chmod 755 {} \;
	find $HOME -type f -exec chmod 644 {} \;
	chmod 700 $HOME/.ssh
	chmod 600 $HOME/.ssh/m7.key
	chmod +x $HOME/bin/m7
	chmod +x $HOME/bin/m7d
	chmod +x $HOME/lib/init.d/m7d
	find $HOME/lib/perl -type f -exec chmod +x {} \;
}

readonly -f git_sync