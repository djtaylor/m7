#!/bin/bash

# Change to a temporary working directory
mkdir /tmp/m7; cd /tmp/m7

# Clone the Git repository
git clone https://github.com/djtaylor/m7.git

# Preserve configuration files
cp ~/lib/perl/modules/M7Config.pm /tmp/m7/.
if [ -f ~/html/dashboard/lib/config.ini ]; then
	cp ~/html/dashboard/lib/config.ini /tmp/m7/.
fi

# Rsync the directories
rsync -a /tmp/m7/m7/ /opt/vpls/m7/.

# Restore configuration files
mv -f /tmp/m7/M7Config.pm ~/lib/perl/modules/.
if [ -f ~/html/dashboard/lib/config.ini ]; then
	mv -f /tmp/m7/config.ini ~/html/dashboard/lib/.
fi

# Leave the working directory and delete it
cd && rm -rf /tmp/m7

# Delete the local '.git' directory
rm -rf ~/.git

# Delete the '.gitignore' files
rm -f ~/output/.gitignore
rm -f ~/log/.gitignore
rm -f ~/plans/.gitignore
rm -f ~/lock/subsys/.gitignore

# Update folder permissions
chmod 755 $HOME
find $HOME -type d -exec chmod 755 {} \;
find $HOME -type f -exec chmod 644 {} \;
chmod 700 $HOME/.ssh
chmod 600 $HOME/.ssh/m7.key
chmod +x $HOME/bin/*
chmod +x $HOME/lib/init.d/m7d
find $HOME/lib/perl -type f -exec chmod +x {} \;