#! /bin/bash
#  TO DO
#  Fix AirVideo section for appropriate restore archive
# #DONE: Fix Config Restores for appropriate restore archive
#  Log more stuff
#  Seperate log for backup and restore
#  SMB user creation for jemily and media
#  fix up mySQL isntall to edit config file
#  fix samba share setup, make interactive

set -e

USER=jemily
GROUP=$USER
HOME_DIRECTORY="/home/$USER/"
LOG_FILE=$HOME_DIRECTORY"installation.log"
DIALOG_WIDTH=70
SCRIPT_TITLE="Jeremy's Ultimate Setup Script"
HOSTNAME=`hostname`
BACKUPNAME=$HOSTNAME-backup-$(date +%Y-%m-%d)
BACKUPDIR=/home/$USER/backup
SMB_TVSHOWSHARE="//bender/tvshows"
SMBCLIENTUSER=
SMBCLIENTPASSWD=
USER=
USERPASSWORD=
MYSQLPASSWD=
BACKUPFILE=
RESTORECONFIG=0
VERBOSE=0
OUTPUT=
XBMCDBNAME=MyVideos75

#_-_-_-_-_-_-_-SETUP FUNCTIONS-_-_-_-_-_-_-_#


function installRequirements()
{
  sudo apt-get install dialog > /dev/null 2>&1
}

function initialSetup()
{
  showInfo "Updating Ubuntu with latest packages (may take a while)..."
  sudo apt-get update > /dev/null 2>&1
  sudo apt-get -y dist-upgrade > /dev/null 2>&1
}

function getConfigs()
{
  showInfo "Acquiring and Extracting config files..."
  tar -xvf configs.tar.gz > /dev/null 2>&1
}

function setupBackup()
{
    mkdir $BACKUPDIR
}

function setupRestore()
{
  tar -xvf backup-*.tar.gz  > /dev/null 2>&1

}

#_-_-_-_-_-_-_-PROGRAM FUNCTIONS-_-_-_-_-_-_-_#

##############
#TRANSMISSION#
##############

function installTransmission()
{
  #add transmission PPA
  showInfo "Installing Transmission PPA"
  sudo apt-get install -y python-software-properties software-properties-common > /dev/null 2>&1
  sudo apt-add-repository -y ppa:transmissionbt/ppa > /dev/null 2>&1
  sudo apt-get update > /dev/null 2>&1

  #transmission Install
  showInfo "Installing Transmission"
  sudo apt-get install -y transmission-daemon > /dev/null 2>&1

  #stop transmission and set it to run as user
  showInfo "Changing Transmission User"
  sudo service transmission-daemon stop > /dev/null 2>&1
  sudo sed -i -e "s/debian-transmission/$USER/g" /etc/init.d/transmission-daemon > /dev/null 2>&1
  sudo chown -R $USER:$GROUP /etc/transmission-daemon > /dev/null 2>&1
  sudo chown -R $USER:$GROUP /var/lib/transmission-daemon > /dev/null 2>&1

  #setup crontab for updating blocklist
  showInfo "Setting up Transmission Cron"
  crontab -l | crontab - > /dev/null 2>&1
  (crontab -l ; echo "5 7 * * sun transmission-remote -n transmission:transmission --blocklist-update") |uniq - | crontab - > /dev/null 2>&1
}

function restoreTransmission()
{
  #setup temp and finished directorys for transmission
  showInfo "Creating folder for Transmission"
  mkdir /home/$USER/transtemp > /dev/null 2>&1
  mkdir /home/$USER/finished > /dev/null 2>&1
  mkdir /home/$USER/finished/tvshows > /dev/null 2>&1

  #copy config file
  showInfo "Restoring Transmission Config File"
  cp backup/transmission/settings.json /etc/transmission-daemon/settings.json > /dev/null 2>&1

  #start transmission and download first blocklist
  showInfo "Downloading first blocklist"
  sudo service transmission-daemon start > /dev/null 2>&1
  sleep 5s
  transmission-remote -n transmission:transmission --blocklist-update > /dev/null 2>&1
  sleep 10s
  sudo service transmission-daemon stop > /dev/null 2>&1
}

function backupTransmission()
{
  showInfo "Backing Up Transmission"
  mkdir $BACKUPDIR/transmission > /dev/null 2>&1
  cp /etc/transmission-daemon/settings.json $BACKUPDIR/transmission > /dev/null 2>&1
}


#########
#FLEXGET#
#########

function installFlexget()
{
  #install Requirements
  showInfo "Installing Flexget Requirements"
  sudo apt-get install -y python2.7 python-pip > /dev/null 2>&1

  #install flexget and transmissionrpc
  showInfo "Installing Flexget and TransmissionRPC"
  sudo pip install flexget > /dev/null 2>&1
  sudo pip install transmissionrpc > /dev/null 2>&1

  #setup crontab for running flexget every 30 minutes
  showInfo "Updating Cron for Flexget"
  (crontab -l ; echo "*/30 * * * * /usr/local/bin/flexget --cron") | uniq - | crontab -
}

function restoreFlexget()
{
  #copy flexget config file
  showInfo "Updating Flexget config files"
  cp -R backup/flexget/.flexget /home/$USER/ > /dev/null 2>&1
}

function backupFlexget()
{
  showInfo "Backing Up Flexget"
  mkdir $BACKUPDIR/flexget > /dev/null 2>&1
  cp -R /home/$USER/.flexget/ $BACKUPDIR/flexget/ > /dev/null 2>&1
}

#########
#FILEBOT#
#########

function installFilebot()
{
  #install requirements
  showInfo "Installing Filebot Requirements"
  sudo apt-get install -y openjdk-7-jre-headless default-jre-headless glib-networking > /dev/null 2>&1

  #download appropriate version of filebot
  showInfo "Downloading Filebot"
  if [ `uname -m` = "i686" ]
  then
     wget -O /tmp/filebot-i386.deb 'http://filebot.sourceforge.net/download.php?type=deb&arch=i386' > /dev/null 2>&1
  else
     wget -O /tmp/filebot-amd64.deb 'http://filebot.sourceforge.net/download.php?type=deb&arch=amd64' > /dev/null 2>&1
  fi

  #extract .deb and manually install
  showInfo "Installing Filebot"
  mkdir /tmp/fb > /dev/null 2>&1
  dpkg-deb -x /tmp/filebot-*.deb /tmp/fb > /dev/null 2>&1
  sudo cp -R /tmp/fb/* / > /dev/null 2>&1
  sudo ln -s /usr/share/filebot/bin/filebot.sh /usr/bin/filebot > /dev/null 2>&1
}

function restoreFilebot()
{
  showInfo "Restoring Filebot Files"
  cp -R /home/$USER/backup/filebot/ /home/$USER/
  
}

function backupFilebot()
{
  showInfo "Backing Up Filebot"
  mkdir $BACKUPDIR/filebot > /dev/null 2>&1
  cp -R /home/$USER/.filebot/ $BACKUPDIR/filebot > /dev/null 2>&1
}



#######
#SAMBA#
#######

function installSamba()
{

  #intall requirements
  showInfo "Installing Samba Requirements"
  sudo apt-get install -y samba cifs-utils > /dev/null 2>&1

}

function restoreSamba()
{
  
  sudo service smbd stop
  sudo cp /home/$USER/backup/samba/smb.conf /etc/samba/smb.conf  > /dev/null 2>&1
  sudo service smbd start
}

function configureSambaDownloader()
{
  #prompt for users password if not passed in from CLI
  if [ -z $USERPASSWORD ]; then
    showInput "please enter `echo $USER` password"
    USERPASSWORD=$OUTPUT
  fi

  #create samba user
  showInfo "Creating SMB User $USER"
  printf "$USERPASSWORD\n$USERPASSWORD\n" | sudo smbpasswd -a -s $USER

  #create finished share
  showInfo "Creating Finished Share"
  sudo service smbd stop > /dev/null 2>&1
  echo "
  [finished]
    path = /home/$USER/finished/
    valid users = $USER
    write list = $USER
  " | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1
  sudo service smbd start > /dev/null 2>&1

  #prompt for SMB client username if not passed in from CLI
  if [ -z $SMBCLIENTUSER ]; then
    showInput "please enter SMB Client username"
    SMBCLIENTUSER=$OUTPUT
  fi

  #prompt for SMB client password if not passed in from CLI
  if [ -z $SMBCLIENTPASSWD ]; then
    showInput "please enter SMB Client password"
    SMBCLIENTPASSWD=$OUTPUT
  fi

  #automount tvshow share
  showInfo "Setting remote tvshow share to automount"
  sudo mkdir /mnt/tvshows > /dev/null 2>&1
  echo "$SMB_TVSHOWSHARE  /mnt/tvshows  cifs  username=$SMBCLIENTUSER,password=$SMBCLIENTPASSWD 0 0" | sudo tee -a /etc/fstab
  sudo mount -a > /dev/null 2>&1
}

function backupSamba()
{
  showInfo "Backing Up Samba"
  mkdir $BACKUPDIR/samba > /dev/null 2>&1
  sudo cp /etc/samba/smb.conf $BACKUPDIR/samba > /dev/null 2>&1
}

########
#JEMUBY#
########

function installJemuby()
{
  #install requirements
  showInfo "Installing Janus/Ruby/Git Requirements"
  sudo apt-get install -y build-essential nodejs tig exuberant-ctags ack-grep vim openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev libgdbm-dev ncurses-dev automake libtool bison subversion pkg-config libffi-dev bash curl git patch bzip2 > /dev/null 2>&1

  #install rvm and latest stable ruby
  showInfo "Installing latest RVM and Ruby"
  \curl -#L https://get.rvm.io | bash -s stable --ruby > /dev/null 2>&1
  source /home/$USER/.rvm/scripts/rvm

  #installing gems
  showInfo "Installing GEMS"
  gem install xml-simple
  gem install httparty
  gem install rails

  #install janus
  showInfo "Installing Janus"
  curl -sLo- https://bit.ly/janus-bootstrap | bash > /dev/null 2>&1

  #get most recent jemuby from github
  showInfo "Installing Jemuby"
  cd /home/$USER/
  git clone git://github.com/spaceout/jemuby.git > /dev/null 2>&1
}

#######
#MYSQL#
#######

function installMysqlXBMC()
{
  #prompt for mysql root password if not passed in from CLI
  if [ -z $MYSQLPASSWD ]; then
    showInput "please enter mysql root password"
    MYSQLPASSWD=$OUTPUT
  fi

  #install requirements
  showInfo "Installing mySQL and phpmyadmin"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -q -y install mysql-server phpmyadmin > /dev/null 2>&1
  mysqladmin -u root password $MYSQLPASSWD
}

function restoreXBMCDB()
{
  
  #setup XBMC database
  showInfo "Creating XBMC user and Databases"
  mysql -u root --password=$MYSQLPASSWD -e "CREATE USER 'xbmc' IDENTIFIED BY 'xbmc';" > /dev/null 2>&1
	mysql -u root --password=$MYSQLPASSWD -e "GRANT ALL ON *.* TO 'xbmc';" > /dev/null 2>&1
	mysql -u root --password=$MYSQLPASSWD -e "CREATE DATABASE $XBMCDBNAME;" > /dev/null 2>&1

  #restore XBMC database
  showInfo "Restoring XBMC Database from backup"
  mysql -u root --password=$MYSQLPASSWD $XBMCDBNAME <  /home/$USER/backup/XBMC/$XBMCDBNAME.sql > /dev/null 2>&1
}

function backupXBMCDB()
{
  showInfo "Backing Up XBMCDB"
  #PROMPT FOR MYSQL ROOT PASSWORD#
  mkdir $BACKUPDIR/XBMCDB > /dev/null 2>&1
  mysqldump -u root --password=$MYSQLPASSWD $XBMCDBNAME > $BACKUPDIR/XBMCDB/$XBMCDBNAME.sql > /dev/null 2>&1
}



##############
#INSTALL XBMC#
##############

function installXBMC()
{
  exit
}

function backupXBMC()
{
  showInfo "Backing Up XBMC"
  mkdir $BACKUPDIR/XBMC > /dev/null 2>&1
  cp -R /home/$USER/.xbmc/ $BACKUPDIR/XBMC > /dev/null 2>&1
}

##################
#INSTALL AIRVIDEO#
##################
function installAirVideo()
{
  #install requirements
  showInfo "Installing AirVideo Requirements"
  sudo apt-get install -y default-jre-headless libavcodec-extra-53 cifs-utils
  
  #install airvideo
  showInfo "Installing AirVideo"
  sudo mkdir /etc/airvideo
  sudo mv /home/$USER/backup/airvideo/* /etc/airvideo
  sudo chown -R root:root /etc/airvideo
  sudo cp /etc/airvideo/airvideo.conf /etc/init/
  
  #set shares to automount
  showInfo "Setting Video Shares to Automount"
  sudo mkdir /mnt/tvshows
  sudo mkdir /mnt/movies
  sudo mkdir /mnt/hdizzle
  echo "
  //bender/tvshows /mnt/tvshows  cifs  username=media,password=m3d1a 0 0
  //flexo/movies   /mnt/movies   cifs  username=media,password=m3d1a 0 0
  //flexo/hdizzle  /mnt/hdizzle  cifs  username=media,password=m3d1a 0 0
  " | sudo tee -a /etc/fstab
  sudo mount -a

  #start airvideo service
  #showInfo "Starting AirVideo Service"
  #sudo service airvideo start
}

#_-_-_-_-_-_-_-BACKUP FUNCTIONS-_-_-_-_-_-_-_#

function initializeBackup()
{
  mkdir $BACKUPDIR
  if [ ! -d "$BACKUPDIR" ]; then
    showError "Unable to create backup directory, exiting...."
    exit
  fi
}

function initializeRestore()
{
  if [ -e /home/$USER/backup.tar.gz ]
  then
    showInfo "Extracting backup file"
    cd /home/$USER/
    tar -xvf backup.tar.gz
  else
    showError "No Backup File Found"
    exit
  fi
}

function backupWrapUp()
{
  showInfo "Compressing Backup"
  cd /home/$USER/
  tar -zcvf $BACKUPNAME.tar.gz backup > /dev/null 2>&1
  rm -rf $BACKUPDIR > /dev/null 2>&1
}

#_-_-_-_-_-_-_-OTHER FUNCTIONS-_-_-_-_-_-_-_#

##################
#SCRIPT UTILITIES#
##################

function showInfo()
{
    CUR_DATE=$(date +%Y-%m-%d" "%H:%M)
    echo "$CUR_DATE - INFO :: $@" >> $LOG_FILE
    dialog --title "Installing & configuring..." --backtitle "$SCRIPT_TITLE" --infobox "\n$@" 5 $DIALOG_WIDTH
}

function showError()
{
    CUR_DATE=$(date +%Y-%m-%d" "%H:%M)
    echo "$CUR_DATE - ERROR :: $@" >> $LOG_FILE
    dialog --title "Error" --backtitle "$SCRIPT_TITLE" --msgbox "$@" 8 $DIALOG_WIDTH
}

function showDialog()
{
	dialog --title "Jeremy's Awsome Install Script" --backtitle "$SCRIPT_TITLE" --msgbox "\n$@" 12 $DIALOG_WIDTH
}

function showInput()
{
  OUTPUT=
  TEMPFILE=`mktemp jusi-XXX`
  dialog --title "Jeremy's Awsome Install Script" --backtitle "$SCRIPT_TITLE" --inputbox "\n$@" 8 $DIALOG_WIDTH 2>$TEMPFILE
  OUTPUT=`cat $TEMPFILE`
  rm $TEMPFILE
}

function showYesNo()
{
  YESNO=
  dialog --title "Delete file" --backtitle "$SCRIPT_TITLE" --yesno "\n$@" 7 $DIALOG_WIDTH 
# Get exit status
# 0 means yes
# 1 means no
# 255 means Esc
  YESNO=$?
}

function createFile()
{
  FILE="$1"
  IS_ROOT="$2"
  REMOVE_IF_EXISTS="$3"
  if [ -e "$FILE" ] && [ "$REMOVE_IF_EXISTS" == "1" ]; then
    sudo rm "$FILE" > /dev/null
  else
    if [ "$IS_ROOT" == "0" ]; then
      touch "$FILE" > /dev/null
    else
      sudo touch "$FILE" > /dev/null
    fi
  fi
}

##############
#SCRIPT MENUS#
##############

function selectBackupRestore()
{
  cmd=(dialog --backtitle "$SCRIPT_TITLE" --radiolist "Please select if you would like to backup or restore:" 15 $DIALOG_WIDTH 3)
  options=(1 "Restore" on
           2 "Backup" off)
  choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
  case ${choice//\"/} in
    1)
      selectInstallPrograms
      ;;
    2)
      selectBackupPrograms
      ;;
  esac
}

function selectInstallPrograms()
{
  initialSetup
  if [[ -n "$BACKUPFILE" ]]; then
    initializeRestore
    RESTORECONFIG=1
  fi
    cmd=(dialog --title "Select which Apps you would like to install" --backtitle "$SCRIPT_TITLE" --checklist "Plese select which applications to install" 15 $DIALOG_WIDTH 6)
  options=(1 "Transmission" off
           2 "Flexget" off
           3 "Filebot" off
           4 "Samba" off
           5 "mySQL (XBMC)" off
           6 "XBMC" off
           7 "AirVideo" off
           8 "Jemuby Ruby Vim Janus" off)
  choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
  for choice in $choices
  do
    case ${choice//\"/} in
      1)
        installTransmission
        if [$RESTORECONFIG == 1];then
          restoreTransmission
        fi
        ;;
      2)
        installFlexget
        if [$RESTORECONFIG == 1];then
          restoreFlexget
        fi
        ;;
      3)
        installFilebot
        if [$RESTORECONFIG == 1];then
          restoreFilebot
        fi
        ;;
      4)
        installSamba
        configureSambaMenu
        ;;
      5)
        installMysqlXBMC
        if [$RESTORECONFIG == 1];then
          restoreXBMCDB
        fi
        ;;
      6)
        installXBMC
        if [$RESTORECONFIG == 1];then
          restoreXBMC
        fi
        ;;
      7)
        installAirVideo
        ;;
      8)
        installJemuby
        ;;
    esac
  done
}

function selectBackupPrograms()
{
  initializeBackup
  cmd=(dialog --title "Select which Apps you would like to backup" --backtitle "$SCRIPT_TITLE" --checklist "Plese select which applications to backup" 15 $DIALOG_WIDTH 6)
  options=(1 "Transmission" off
           2 "Flexget" off
           3 "Filebot" off
           4 "Samba" off
           5 "XBMC Userdata" off
           6 "XBMC mySQL DB" off)
  choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
  for choice in $choices
  do
    case ${choice//\"/} in
      1)
        backupTransmission
        ;;
      2)
        backupFlexget
        ;;
      3)
        backupFilebot
        ;;
      4)
        backupSamba
        ;;
      5)
        backupXBMC
        ;;
      6)
        backupXBMCDB
        ;;
    esac
  done
  backupWrapUp
}

function configureSambaMenu()
{
  cmd=(dialog --backtitle "$SCRIPT_TITLE" --radiolist "Please select samba configuration" 15 $DIALOG_WIDTH 3)
  options=(1 "Downloader (share out /user/home/finished/" on
           2 "Server/Custom (restore smb.conf)" off)
  choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
  case ${choice//\"/} in
    1)
      configureSambaDownloader
      ;;
    2)
      restoreSamba
      ;;
  esac
}


#######################
#PROCESS CLI ARGUMENTS#
#######################

usage()
{
  cat << EOF
  Jem's Ultimate Script

  OPTIONS:
     -h      Show this message
     -u      username
     -m      mySQL Root Password
     -b      backup file
     -v      Verbose
EOF
}

while getopts “hu:m:b:v” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      USER=$OPTARG
      ;;
    m)
      MYSQLPASSWD=$OPTARG
      ;;
    b)
      BACKUPFILE=$OPTARG
      ;;
    v)
      VERBOSE=1
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

##############
#BEGIN SCRIPT#
##############

clear
createFile "$LOG_FILE" 0 1
echo "Installing Initial Requirements....."
installRequirements
echo "Loading installer..."
showDialog "Welcome to Jeremy's Ultimate Script.  Some parts might take some time. \n\nPlease be Patient..."
selectBackupRestore
showDialog "All Operations Completed Successfully!"
clear

