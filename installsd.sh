 #!/bin/bash
 #   SD bash install script
 #   (c) 2023-2026 Donald Montaine and Mark Buller
 #   This software is released under the Blue Oak Model License
 #   a copy can be found on the web here: https://blueoakcouncil.org/license/1.0.0
 #
 #   rev 1.0-0 Dec 25 dsm - modified to handle Arch based distributions
 #   rev 0.9-4 Dec 16 dsm - manual choice of distro rather they trying to determine automatically
 #   rev 0.9-2 Nov 27 dsm - create one-stop install script
 #   rev 0.9-3 Nov 25 mab   update script to install from repo
 #                          move voc back to dynamic file
 #                          correct ownership issue with /home/sd when re installing and /home/sd already exists
 #   rev 0.9-1 Apr 25 mab - replace lsb_release with /etc/os-release - not installed by default on Fedora
 #   rev 0.9-1 Mar 25 mab - create generic install script and make corrections needed for Raspberry install
 #   rev 0.9-1 Mar 25 mab - add optional install of TAPE / RESTORE subsystem
 #   rev 0.9.0 Jan 25 mab - tighten up permissions
 #                        - build with embedded python
 #                        - sdsys's pri group now sdusers - note require sudo groupdel sdsys in deletesd.sh
 #                        - comment define statement in file sdsys/GPL.BP/define_install.h and recompile CPROC at end of install,
 #
 if [[ $EUID -eq 0 ]]; then
  echo "This script must NOT be run as root" 1>&2
  exit
fi
if [ -f  "/usr/local/sdsys/bin/sd" ]; then
  echo "A version of sd is already installed."
  echo "Uninstall it before running this script."
  exit
fi
#
tgroup=sdusers
tuser=$USER
cwd=$(pwd)
sdsysdir="/usr/local/sdsys"
#
clear
echo -e "\e[91mSD installer\e[0m"
echo -----------------------
echo
echo -e "\e[92mFor this install script to work you must have sudo installed"
echo "and be a member of the sudo group.  Also, systemd must be enabled."
echo
echo "Installer tested on Debian 13, Fedora 43, Manjaro 25 and Ubuntu 24.04."
echo
echo "This script will download the SD source code, compile and install SD."
echo
echo "WARNING: Any existing sdb64 directory under the current directory"
echo "         will be deleted by this script."
echo

echo -e "\e[93m" 
read -p "Continue? (y/N) " yn
echo -e "\e"
case $yn in
    [yY] ) echo;;
    [nN] ) exit;;
    * ) exit ;;
esac

echo
echo "If requested, enter your account password:"
sudo date &>/dev/null
clear
echo
rm -fr $cwd/sdb64
echo -e "\e[0m"
# Ask for distribution type
is_arch=0
is_debian=0
is_fedora=0
echo -e "\e[92mChoose your distribution."
echo
echo " Enter <A> if you are istalling on an Arch based distribution." 
echo " Enter <D> if you are installing on a Debian or Ubuntu based distribution."
echo " Enter <F> if you are installing on a Fedora Based distribution."
echo " Or press enter with no entry to exit the installer."
echo -e "\e[93m"
read -p "Continue? (a/d/f) " adf
echo -e "\e[0m"
case $adf in
    [aA] ) is_arch=1;;
    [dD] ) is_debian=1;;
    [fF] ) is_fedora=1;;
    * ) exit ;;
esac
 # package installer is based on distro, clunky but easy to read
 if [ $is_arch -eq 1 ]; then
     sudo pacman -S git base-devel micro lynx libbsd libsodium openssh python
     if [ $? -ne 0 ]; then
         echo -e "\e[91m"
         echo "Package installation using pacman failed.  Exiting script."
         echo "Verify your internet connection and then try again."
         echo -e "\e[0m"
         exit
     else   
         sudo systemctl start sshd
         sudo systemctl enable sshd
     fi
 fi
 #
 if [ $is_debian -eq 1 ]; then
     sudo apt-get -y install git build-essential micro lynx libbsd-dev libsodium-dev openssh-server python3-dev
     if [ $? -ne 0 ]; then
         echo -e "\e[91m"
         echo "Package installation using apt-get failed.  Exiting script."
         echo "Verify your internet connection and then try again."
         echo -e "\e[0m"
         exit
     fi
 fi
 #
 if [ $is_fedora -eq 1 ]; then
     sudo dnf -y install git make automake gcc gcc-c++ kernel-devel micro lynx libbsd-devel libsodium-devel openssh-server python3-devel
     if [ $? -ne 0 ]; then
         echo -e "\e[91m"
         echo "Package installation using dnf failed.  Exiting script."
         echo "Verify your internet connection and then try again."
         echo -e "\e[0m"
         exit
     fi
 fi

 # check that sdb64 repository is accessible
 REPO_URL="https://github.com/stringdatabase/sdb64" # Replace with the actual repository URL
 echo "using repo at: $REPO_URL"
 # Attempt to list remote references silently
  git ls-remote -q "$REPO_URL" &>/dev/null
 # Check the exit status of the previous command
 if [[ $? -eq 0 ]]; then
     echo "The Github repository at github.com is available."
     echo "Creating temporary source code repository."
     echo -e "\e[93m"
     read -p "Install the <M>ain or <D>evelopment version? (M/d) " md
     echo -e "\e[0m"
     case $md in
         [mM] ) echo "Installing the main version."
                git clone -b main $REPO_URL;;
         [dD] ) echo "Installing the development version."
                git clone -b dev $REPO_URL;;
         * )    echo "Installing the main version."
                git clone -b main $REPO_URL;;
     esac
 else
     echo -e "\e[91m"
     echo "Sdb64 repository is not available."
     echo "Verify your internet connection and then try again."
     echo -e "\e[0m"
     exit
 fi

 cd $cwd/sdb64

 # rev 0.9.0 need python dev to build, did we get it?
 python3 --version
 if [ $? -eq 0 ]; then
     # got it, what version and where are the include files?
     PY_HDRS=$(python3-config --includes)
     # remove the first "-I"
     # and get the first path (for some reason its output twice?
     HDRS_STR="${PY_HDRS%% *}"
     HDRS_STR="${HDRS_STR#-I}"
     #
     echo "path to include file: " $HDRS_STR
     # now create the include file we will use
     echo "#include <"$HDRS_STR"/Python.h>" > sd64/gplsrc/sdext_python_inc.h
 else
     echo -e "\e[91mPython missing, Cannot build!\e[0m"
     exit
 fi

 cd $cwd/sdb64/sd64

 sudo make
 # rev 0.9.0 if make fails, abort install
 if [ $? -eq 0 ]; then
     echo "Successful Build."
 else
     echo -e "\e[91m"
     echo "Could not build SD. Install terminated!"
     echo -e "\e[0m"
     exit
 fi

# Create sd system user and group
echo "Creating group: sdusers."
sudo groupadd --system sdusers
sudo usermod -a -G sdusers root

echo "Creating user: sdsys."
sudo useradd --system sdsys -G sdusers
echo "Setting user: sdsys default group to sdusers."
sudo usermod -g sdusers sdsys

sudo cp -R sdsys /usr/local
# Fool sd's vm into thinking gcat is populated
sudo touch /usr/local/sdsys/gcat/\$CPROC
# create errlog
sudo touch /usr/local/sdsys/errlog

# install TAPE and RESTORE system?
echo -e "\e[93m"
read -p "Install TAPE and RESTORE subsystem? (y/N) " yn
echo -e "\e[0m"
case $yn in
    [yY] )  echo "Copying TAPE and RESTORE programs to GPL.BP."
         sudo cp tape/GPL.BP/* /usr/local/sdsys/GPL.BP
         echo "Copying TAPE and RESTORE verbs to VOC."
         sudo cp -R tape/VOC/* /usr/local/sdsys/VOC_TEMPLATE
         echo ;;
esac


# copy install template
sudo cp -R bin $sdsysdir
sudo cp -R gplsrc $sdsysdir
sudo cp -R gplobj $sdsysdir
sudo mkdir $sdsysdir/gplbld
sudo cp -R gplbld/FILES_DICTS $sdsysdir/gplbld/FILES_DICTS
sudo cp -R terminfo $sdsysdir

# build program objects for bootstrap install
sudo python3 gplbld/bbcmp.py $sdsysdir GPL.BP/BBPROC GPL.BP.OUT/BBPROC
sudo python3 gplbld/bbcmp.py $sdsysdir GPL.BP/BCOMP GPL.BP.OUT/BCOMP
sudo python3 gplbld/bbcmp.py $sdsysdir GPL.BP/PATHTKN GPL.BP.OUT/PATHTKN
sudo python3 gplbld/pcode_bld.py

sudo cp Makefile $sdsysdir
sudo cp gpl.src $sdsysdir
sudo cp terminfo.src $sdsysdir

sudo chown -R sdsys:sdusers $sdsysdir
sudo chown root:root $sdsysdir/ACCOUNTS/SDSYS
sudo chmod 654 $sdsysdir/ACCOUNTS/SDSYS
sudo chown -R sdsys:sdusers $sdsysdir/terminfo

 sudo cp sd.conf /etc/sd.conf
 sudo chmod 644 /etc/sd.conf
 sudo chmod -R 755 $sdsysdir
 sudo chmod 775 $sdsysdir/errlog
 sudo chmod -R 775 $sdsysdir/prt

 #   Add $tuser to sdusers group
 sudo usermod -aG sdusers $tuser

 # directories for sd accounts
 ACCT_PATH=/home/sd
 if [ ! -d "$ACCT_PATH" ]; then
    sudo mkdir -p "$ACCT_PATH"/user_accounts
    sudo mkdir "$ACCT_PATH"/group_accounts
 fi  
 
 # rev 0.9.3 always set ownership (these could get messed up if sdsys and sdusers group gets deleted during deletesd.sh script	
 sudo chown sdsys:sdusers "$ACCT_PATH"
 sudo chmod 775 "$ACCT_PATH"
 sudo chown sdsys:sdusers "$ACCT_PATH"/group_accounts
 sudo chmod 775 "$ACCT_PATH"/group_accounts
 sudo chown sdsys:sdusers "$ACCT_PATH"/user_accounts
 sudo chmod 775 "$ACCT_PATH"/user_accounts

 sudo ln -s $sdsysdir/bin/sd /usr/local/bin/sd

 # Install sd service for systemd
 SYSTEMDPATH=/usr/lib/systemd/system

 if [ -d  "$SYSTEMDPATH" ]; then
     if [ -f "$SYSTEMDPATH/sd.service" ]; then
         echo "SD systemd service is already installed."
     else
         echo "Installing sd.service for systemd."

         sudo cp usr/lib/systemd/system/* $SYSTEMDPATH

         sudo chown root:root $SYSTEMDPATH/sd.service
         sudo chown root:root $SYSTEMDPATH/sdclient.socket
         sudo chown root:root $SYSTEMDPATH/sdclient@.service

         sudo chmod 644 $SYSTEMDPATH/sd.service
         sudo chmod 644 $SYSTEMDPATH/sdclient.socket
         sudo chmod 644 $SYSTEMDPATH/sdclient@.service
     fi
 fi

 # Copy saved directories if they exist
 if [ -d /home/sd/ACCOUNTS ]; then
     echo Moved existing ACCOUNTS directory
     sudo rm -fr $sdsysdir/ACCOUNTS
     sudo mv /home/sd/ACCOUNTS $sdsysdir
 else
     echo Saved Accounts Directory Does Not Exist
 fi

 #   Start SD server
 echo "Starting SD server."
 sudo $sdsysdir/bin/sd -start
 echo
 echo "Bootstap pass 1."
 sudo $sdsysdir/bin/sd -i

 # files added in pass1 need perm and owner setup
 sudo chmod -R 755 $sdsysdir/\$HOLD.DIC
 sudo chmod -R 775 $sdsysdir/\$IPC
 sudo chmod -R 755 $sdsysdir/\$MAP
 sudo chmod -R 755 $sdsysdir/\$MAP.DIC
 sudo chmod -R 755 $sdsysdir/VOC
 sudo chmod -R 755 $sdsysdir/ACCOUNTS.DIC
 sudo chmod -R 755 $sdsysdir/DICT.DIC
 sudo chmod -R 755 $sdsysdir/DIR_DICT
 sudo chmod -R 755 $sdsysdir/VOC.DIC
 #
 sudo chown -R sdsys:sdusers  $sdsysdir/\$HOLD.DIC
 sudo chown -R sdsys:sdusers  $sdsysdir/\$IPC
 sudo chown -R sdsys:sdusers  $sdsysdir/\$MAP
 sudo chown -R sdsys:sdusers  $sdsysdir/\$MAP.DIC
 sudo chown -R sdsys:sdusers  $sdsysdir/VOC
 sudo chown -R sdsys:sdusers  $sdsysdir/ACCOUNTS.DIC
 sudo chown -R sdsys:sdusers  $sdsysdir/DICT.DIC
 sudo chown -R sdsys:sdusers  $sdsysdir/DIR_DICT
 sudo chown -R sdsys:sdusers  $sdsysdir/VOC.DIC

 echo "Bootstap pass 2."
 sudo $sdsysdir/bin/sd -internal SECOND.COMPILE
 
 echo "Bootstap pass 3."
 sudo $sdsysdir/bin/sd RUN GPL.BP WRITE_INSTALL_DICTS NO.PAGE
 
 echo "Compiling C and I type dictionaries."
 sudo $sdsysdir/bin/sd THIRD.COMPILE

 echo "Compiling CPROC without IS_INSTALL defined."
 sudo bash -c 'echo "*comment out * $define IS_INSTALL" > /usr/local/sdsys/GPL.BP/define_install.h'
 sudo bin/sd -internal BASIC GPL.BP CPROC
 sudo chmod -R 755 $sdsysdir/gcat

 #  create a user account for the current user
 echo
 echo
 if [ ! -d /home/sd/user_accounts/$tuser ]; then
     echo "Creating a user account for" $tuser "."
     sudo bin/sd create-account USER $tuser no.query
 fi

 echo
 echo Stopping sd
 sudo $sdsysdir/bin/sd -stop
 sleep 1
 
 echo
 echo Enabling services
 sudo systemctl start sd.service
 sudo systemctl start sdclient.socket
 sudo systemctl enable sd.service
 sudo systemctl enable sdclient.socket
 
 sleep 1
 sudo $sdsysdir/bin/sd -stop
 sleep 1
 sudo $sdsysdir/bin/sd -start
 sleep 1
 sudo $sdsysdir/bin/sd -stop

 echo
 echo Compiling terminfo database
 sudo $cwd/sdb64/sd64/bin/sdtic -v $cwd/sdb64/sd64/terminfo.src
 echo Terminfo compilation complete
 sudo cp $cwd/sdb64/sd64/terminfo.src $sdsysdir
 echo
 rm -fr $cwd/sdb64
 cd $cwd

 # display end of script message
 echo
 echo ---------------------------------------------------------------
 echo -e "\e[91mThe SD server is installed.\e[33m"
 echo "---------------------------"
 echo
 echo -e "\e[92mThe temporary source code directory used during the install"
 echo "has been deleted."
 echo
 echo "The deletesd.sh script has been copied to the current directory."
 echo "Use it if you want to uninstall SD."
 echo
 echo "The /home/sd directory has been created."
 echo "User directories are created under /home/sd/user_accounts."
 echo "Group directories are created under /home/sd/group_accounts."
 echo "Accounts are only created using CREATE-ACCOUNT in SD."
 echo
 echo "Reboot to assure that group memberships are updated"
 echo "and the APIsrvr Service is enabled."
 echo "Note: In rare cases it requires two reboots for sd to autostart"
 
 echo
 echo -e "After rebooting, open a terminal and enter \'sd\' "
 echo "to connect to your sd home directory."
 echo
 echo -e "\e[0m----------------------------------------------------------------"
 echo -e "\e[93m"
 read -p "Restart Computer? (y/N) " yn
 echo -e "\e[0m"
 case $yn in
     [yY] ) sudo reboot;;
     [nN] ) echo;;
     * ) echo ;;
 esac
 exit
