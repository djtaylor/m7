#!/bin/bash

# Check if SELinux is enabled and Apache installed
SELINUX_ENABLED="$(sestatus | grep -i 'enabled')"
APACHE_INSTALLED="$(rpm -qa | grep -e "^httpd-[0-9].*$")"

# Get the target branch and set the temporary directory and M7 home
GIT_BRANCH="$1"
TMP_DIR=/tmp/m7-$GIT_BRANCH

# Change to a temporary working directory
mkdir $TMP_DIR; cd $TMP_DIR
if [ -z $TMP_DIR ]; then
	echo -e "Failed to set the TMP_DIR variable..."
	exit 1;
fi

# Set the M7 home director
if [ $GIT_BRANCH = "dev" ]; then
	M7_HOME="/opt/vpls/m7-dev"
else
	M7_HOME="/opt/vpls/m7"
fi

# Show the directories
echo -e "Git Branch: '$GIT_BRANCH'"
echo -e "Temporary Director: '$TMP_DIR'"
echo -e "M7 Home: '$M7_HOME'"

# Clone the Git repository
git clone -b $GIT_BRANCH https://github.com/djtaylor/m7.git

# Make sure the git clone was successfull
if [ "$?" != "0" ]; then
	echo -e "Git clone failed, please verify your network settings..."
    rm -rf $TMP_DIR
    exit 1;
fi

# Preserve configuration files
cp $M7_HOME/lib/perl/modules/M7Config.pm $TMP_DIR/.
cp $M7_HOME/html/lib/config.ini $TMP_DIR/.

# Rsync the directories
rsync -a $TMP_DIR/m7/ $M7_HOME/.

# Restore configuration files
mv -f $TMP_DIR/M7Config.pm $M7_HOME/lib/perl/modules/.
mv -f $TMP_DIR/config.php $M7_HOME/html/lib/.

# Leave the working directory and delete it
cd && rm -rf $TMP_DIR

# Delete the local '.git' directory
rm -rf $M7_HOME/.git

# Delete the '.gitignore' files
rm -f $M7_HOME/output/.gitignore
rm -f $M7_HOME/log/.gitignore
rm -f $M7_HOME/plans/.gitignore
rm -f $M7_HOME/lock/subsys/.gitignore

# Update folder permissions
chmod 755 $M7_HOME
find $M7_HOME -type d -exec chmod 755 {} \;
find $M7_HOME -type f -exec chmod 644 {} \;

# Make sure required files are executable
chmod +x $M7_HOME/bin/*
chmod +x $M7_HOME/lib/init.d/m7d
find $M7_HOME/lib/perl -type f -exec chmod +x {} \;

# Set SSH directory permissions
chmod 700 $M7_HOME/.ssh
chmod 600 $M7_HOME/.ssh/m7.key

# Set SELinux contexts if enabled
if [ ! -z "$SELINUX_ENABLED" ]; then
	chcon -R system_u:object_r:ssh_home_t:s0 $M7_HOME/.ssh
        
	# If Apache server is installed
	if [ ! -z "$APACHE_INSTALLED" ]; then
    	chcon -R system_u:object_r:httpd_sys_content_t:s0 $M7_HOME/html
    fi
fi