#!/bin/bash
#
# 	SD bash delete script
# 	(c) 2023 Donald Montaine
#	This software is released under the Blue Oak Model License
#	a copy can be found on the web here: https://blueoakcouncil.org/license/1.0.0
#
#   rev 0.9.4 Dec 11 2025 Add color
#   rev 0.9.0 Jan 25 mab must remove group sdsys (no longer sdsys's pri group)
#
if [[ $EUID -eq 0 ]]; then
	echo -e "\e[91mThis script must NOT be run as root.\e[0m" 1>&2
	exit
fi
if [ -f  "/usr/local/sdsys/bin/sd" ]; then
	echo
else
	echo -e "\e[91mSD is not installed!"
	echo -e "This script will not run.\e[0m"
	exit
fi
#
clear
echo -e "\e[91mREMOVE the SD Database Completely"
echo "---------------------------------"
echo -e "\e[93m"
read -p "Continue? (y/N) " yn
case $yn in
     [yY] ) echo;;
     [nN] ) exit;;
     * ) exit ;;
esac

echo
echo "If requested, enter your account password:"
sudo date &>/dev/null
echo
echo -e "\e[92mDo you want to save /home/sd and all subdirectories."
echo "WARNING: Choose 'R' to retain accounts for SD reinstallation."
echo "         Choose 'D' will delete all SD User and Group accounts."
echo 
echo -e "\e[93m"
read -p "Delete /home/sd? (R/d) " rd
case $rd in
	[dD] )  echo
	        echo /home/sd Directory Deleted;
			sudo rm -fr /home/sd;;
	* )  
	        echo
		    echo Saving Accounts Directory;
		    sudo mv /usr/local/sdsys/ACCOUNTS /home/sd;
esac
echo -e "\e[0m"

# remove the /usr/sdsys directory
sudo rm -fr /usr/local/sdsys
echo
echo "Removed /usr/local/sdsys directory."

# remove the symbolic link to sd in /usr/local/bin or /usr/bin
if [ -L "/usr/local/bin/sd" ]; then
	sudo rm /usr/local/bin/sd
	echo "Removed symbolic link /usr/local/bin/sd."
fi

if [ -L "/usr/bin/sd" ]; then
	sudo rm /usr/bin/sd
	echo "Removed symbolic link /usr/bin/sd."
fi

#remove config file
sudo rm /etc/sd.conf
echo "Config file removed."
#
cd /usr/lib/systemd/system

#stop services
sudo systemctl stop sd.service
sudo systemctl stop sdclient.socket

# disable services
sudo systemctl disable sd.service
sudo systemctl disable sdclient.socket

# remove service files
sudo rm /usr/lib/systemd/system/sd.service
sudo rm /usr/lib/systemd/system/sdclient.socket
sudo rm /usr/lib/systemd/system/sdclient@.service
echo "Removed systemd service files."

# remove sdsys user and sdusers group
sudo userdel sdsys
sudo groupdel sdusers
sudo groupdel sdsys

echo "Removed sdsys user and sdusers group."

echo -e "\e[92m"
echo "----------------------------------------------"
echo "The deletesd.sh script has completed."
echo "Reboot to update user and group information."
echo "----------------------------------------------"
echo -e "\e[93m"
read -p "Restart computer now? (y/N) " yn
case $yn in
	[yY] ) sudo reboot;;
	[nN] ) echo;;
	* ) echo ;;
esac
echo -e "\e[0m"
