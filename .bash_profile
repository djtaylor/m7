# .bash_profile
umask 022

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs
export HOME=~
export PATH=$PATH:$HOME/bin:/opt/vpls/m7/bin