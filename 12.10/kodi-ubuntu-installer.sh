#!/bin/bash
#
# @original author   Bram van Oploo
# @author  Matt Filetto
# @date     2013-12-27
# @version  0.93
#

KODI_USER="kodi"
THIS_FILE=$0
SCRIPT_VERSION="0.93"
VIDEO_DRIVER=""
HOME_DIRECTORY="/home/$KODI_USER/"
KERNEL_DIRECTORY=$HOME_DIRECTORY"kernel/"
TEMP_DIRECTORY=$HOME_DIRECTORY"temp/"
ENVIRONMENT_FILE="/etc/environment"
CRONTAB_FILE="/etc/crontab"
DIST_UPGRADE_FILE="/etc/cron.d/dist_upgrade.sh"
DIST_UPGRADE_LOG_FILE="/var/log/updates.log"
KODI_ADDONS_DIR=$HOME_DIRECTORY".kodi/addons/"
KODI_USERDATA_DIR=$HOME_DIRECTORY".kodi/userdata/"
KODI_KEYMAPS_DIR=$KODI_USERDATA_DIR"keymaps/"
KODI_ADVANCEDSETTINGS_FILE=$KODI_USERDATA_DIR"advancedsettings.xml"
KODI_INIT_CONF_FILE="/etc/init/kodi.conf"
KODI_XSESSION_FILE="/home/kodi/.xsession"
UPSTART_JOB_FILE="/lib/init/upstart-job"
XWRAPPER_FILE="/etc/X11/Xwrapper.config"
GRUB_CONFIG_FILE="/etc/default/grub"
GRUB_HEADER_FILE="/etc/grub.d/00_header"
SYSTEM_LIMITS_FILE="/etc/security/limits.conf"
INITRAMFS_SPLASH_FILE="/etc/initramfs-tools/conf.d/splash"
INITRAMFS_MODULES_FILE="/etc/initramfs-tools/modules"
XWRAPPER_CONFIG_FILE="/etc/X11/Xwrapper.config"
MODULES_FILE="/etc/modules"
REMOTE_WAKEUP_RULES_FILE="/etc/udev/rules.d/90-enable-remote-wakeup.rules"
AUTO_MOUNT_RULES_FILE="/etc/udev/rules.d/media-by-label-auto-mount.rules"
SYSCTL_CONF_FILE="/etc/sysctl.conf"
RSYSLOG_FILE="/etc/init/rsyslog.conf"
POWERMANAGEMENT_DIR="/etc/polkit-1/localauthority/50-local.d/"
DOWNLOAD_URL="https://github.com/jknight2014/xbmc-ubuntu-minimal/raw/patch-1/12.10/download/"
KODI_PPA="ppa:team-xbmc/ppa"
KODI_PPA_UNSTABLE="ppa:team-xbmc/unstable"
HTS_TVHEADEND_PPA="ppa:jabbors/hts-stable"
OSCAM_PPA="ppa:oscam/ppa"
XSWAT_PPA="ppa:ubuntu-x-swat/x-updates"
MESA_PPA="ppa:wsnipex/mesa"

LOG_FILE=$HOME_DIRECTORY"kodi_installation.log"
DIALOG_WIDTH=70
SCRIPT_TITLE="KODI ubuntuniversal minimal installer v$SCRIPT_VERSION for Ubuntu 12.04 to 14.04 by Matt Filetto :: matt.filetto@gmail.com"

GFX_CARD=$(lspci |grep VGA |awk -F: {' print $3 '} |awk {'print $1'} |tr [a-z] [A-Z])

# import Ubuntu release variables
. /etc/lsb-release

## ------ START functions ---------

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
	dialog --title "KODI installation script" \
		--backtitle "$SCRIPT_TITLE" \
		--msgbox "\n$@" 12 $DIALOG_WIDTH
}

function update()
{
    sudo apt-get update > /dev/null 2>&1
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

function createDirectory()
{
    DIRECTORY="$1"
    GOTO_DIRECTORY="$2"
    IS_ROOT="$3"
    
    if [ ! -d "$DIRECTORY" ];
    then
        if [ "$IS_ROOT" == "0" ]; then
            mkdir -p "$DIRECTORY" > /dev/null 2>&1
        else
            sudo mkdir -p "$DIRECTORY" > /dev/null 2>&1
        fi
    fi
    
    if [ "$GOTO_DIRECTORY" == "1" ];
    then
        cd $DIRECTORY
    fi
}

function handleFileBackup()
{
    FILE="$1"
    BACKUP="$1.bak"
    IS_ROOT="$2"
    DELETE_ORIGINAL="$3"

    if [ -e "$BACKUP" ];
	then
	    if [ "$IS_ROOT" == "1" ]; then
	        sudo rm "$FILE" > /dev/null 2>&1
		    sudo cp "$BACKUP" "$FILE" > /dev/null 2>&1
	    else
		    rm "$FILE" > /dev/null 2>&1
		    cp "$BACKUP" "$FILE" > /dev/null 2>&1
		fi
	else
	    if [ "$IS_ROOT" == "1" ]; then
		    sudo cp "$FILE" "$BACKUP" > /dev/null 2>&1
		else
		    cp "$FILE" "$BACKUP" > /dev/null 2>&1
		fi
	fi
	
	if [ "$DELETE_ORIGINAL" == "1" ]; then
	    sudo rm "$FILE" > /dev/null 2>&1
	fi
}

function appendToFile()
{
    FILE="$1"
    CONTENT="$2"
    IS_ROOT="$3"
    
    if [ "$IS_ROOT" == "0" ]; then
        echo "$CONTENT" | tee -a "$FILE" > /dev/null 2>&1
    else
        echo "$CONTENT" | sudo tee -a "$FILE" > /dev/null 2>&1
    fi
}

function addRepository()
{
    REPOSITORY=$@
    KEYSTORE_DIR=$HOME_DIRECTORY".gnupg/"
    createDirectory "$KEYSTORE_DIR" 0 0
    sudo add-apt-repository -y $REPOSITORY > /dev/null 2>&1

    if [ "$?" == "0" ]; then
        update
        showInfo "$REPOSITORY repository successfully added"
        echo 1
    else
        showError "Repository $REPOSITORY could not be added (error code $?)"
        echo 0
    fi
}

function isPackageInstalled()
{
    PACKAGE=$@
    sudo dpkg-query -l $PACKAGE > /dev/null 2>&1
    
    if [ "$?" == "0" ]; then
        echo 1
    else
        echo 0
    fi
}

function isModuleLoaded()
{
    MODULE=$@
	if [ `lsmod | grep -o ^$MODULE` ] 
	then 
		echo 1
	else 
		echo 0
	fi 
}



function aptInstall()
{
    PACKAGE=$@
    IS_INSTALLED=$(isPackageInstalled $PACKAGE)

    if [ "$IS_INSTALLED" == "1" ]; then
        showInfo "Skipping installation of $PACKAGE. Already installed."
        echo 1
    else
        sudo apt-get -f install > /dev/null 2>&1
        sudo apt-get -y install $PACKAGE > /dev/null 2>&1
        
        if [ "$?" == "0" ]; then
            showInfo "$PACKAGE successfully installed"
            echo 1
        else
            showError "$PACKAGE could not be installed (error code: $?)"
            echo 0
        fi 
    fi
}

function download()
{
    URL="$@"
    wget -q "$URL" > /dev/null 2>&1
}

function move()
{
    SOURCE="$1"
    DESTINATION="$2"
    IS_ROOT="$3"
    
    if [ -e "$SOURCE" ];
	then
	    if [ "$IS_ROOT" == "0" ]; then
	        mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1
	    else
	        sudo mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1
	    fi
	    
	    if [ "$?" == "0" ]; then
	        echo 1
	    else
	        showError "$SOURCE could not be moved to $DESTINATION (error code: $?)"
	        echo 0
	    fi
	else
	    showError "$SOURCE could not be moved to $DESTINATION because the file does not exist"
	    echo 0
	fi
}

------------------------------

function installDependencies()
{
    echo "-- Installing script dependencies..."
    echo ""
        sudo apt-get -y install python-software-properties > /dev/null 2>&1
	sudo apt-get -y install dialog software-properties-common > /dev/null 2>&1
}

function fixLocaleBug()
{
    createFile $ENVIRONMENT_FILE
    handleFileBackup $ENVIRONMENT_FILE 1
    appendToFile $ENVIRONMENT_FILE "LC_MESSAGES=\"C\""
    appendToFile $ENVIRONMENT_FILE "LC_ALL=\"en_US.UTF-8\""
	showInfo "Locale environment bug fixed"
}

function fixUsbAutomount()
{
    handleFileBackup "$MODULES_FILE" 1 1
    appendToFile $MODULES_FILE "usb-storage"
    createDirectory "$TEMP_DIRECTORY" 1 0
    download $DOWNLOAD_URL"media-by-label-auto-mount.rules"

    if [ -e $TEMP_DIRECTORY"media-by-label-auto-mount.rules" ]; then
	    IS_MOVED=$(move $TEMP_DIRECTORY"media-by-label-auto-mount.rules" "$AUTO_MOUNT_RULES_FILE")
	    showInfo "USB automount successfully fixed"
	else
	    showError "USB automount could not be fixed"
	fi
}

function applyXbmcNiceLevelPermissions()
{
	createFile $SYSTEM_LIMITS_FILE
    appendToFile $SYSTEM_LIMITS_FILE "$KODI_USER             -       nice            -1"
	showInfo "Allowed KODI to prioritize threads"
}

function addUserToRequiredGroups()
{
	sudo adduser $KODI_USER video > /dev/null 2>&1
	sudo adduser $KODI_USER audio > /dev/null 2>&1
	sudo adduser $KODI_USER users > /dev/null 2>&1
	sudo adduser $KODI_USER fuse > /dev/null 2>&1
	sudo adduser $KODI_USER cdrom > /dev/null 2>&1
	sudo adduser $KODI_USER plugdev > /dev/null 2>&1
        sudo adduser $KODI_USER dialout > /dev/null 2>&1
	showInfo "KODI user added to required groups"
}

function addXbmcPpa()
{
    cmd=(dialog --title "Which KODI PPA?" \
        --backtitle "$SCRIPT_TITLE" \
        --radiolist "Which KODI PPA would you like to use? The official stable PPA will install the current release version of KODI or you can use the unstable PPA which will install the current testing (Alpha/Beta/RC) version of KODI. If unsure use the default Official PPA." 
        15 $DIALOG_WIDTH 6)
        
    options=(1 "Official PPA - Install the release version. (xbmc)" on
             2 "Unstable PPA - Install the Alpha/Beta/RC version. (Kodi)" off)
         
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    case ${choice//\"/} in
        1)
            showInfo "Adding official team-kodi PPA..."
            IS_ADDED=$(addRepository "$KODI_PPA")
            ;;
        2)
            showInfo "Adding unstable team-kodi PPA..."
            IS_ADDED=$(addRepository "$KODI_PPA_UNSTABLE")
            ;;
        *)
            addXbmcPpa
            ;;
    esac
}

function distUpgrade()
{
    showInfo "Updating Ubuntu with latest packages (may take a while)..."
	update
	sudo apt-get -y dist-upgrade > /dev/null 2>&1
	showInfo "Ubuntu installation updated"
}

function installXinit()
{
    showInfo "Installing xinit..."
    IS_INSTALLED=$(aptInstall xinit)
}

function installPowerManagement()
{
    showInfo "Installing power management packages..."
    createDirectory "$TEMP_DIRECTORY" 1 0
    sudo apt-get install -y policykit-1 > /dev/null 2>&1
    sudo apt-get install -y upower > /dev/null 2>&1
    sudo apt-get install -y udisks > /dev/null 2>&1
    sudo apt-get install -y acpi-support > /dev/null 2>&1
    sudo apt-get install -y consolekit > /dev/null 2>&1
    sudo apt-get install -y pm-utils > /dev/null 2>&1
	download $DOWNLOAD_URL"custom-actions.pkla"
	createDirectory "$POWERMANAGEMENT_DIR"
    IS_MOVED=$(move $TEMP_DIRECTORY"custom-actions.pkla" "$POWERMANAGEMENT_DIR")
}

function installAudio()
{
    showInfo "Installing audio packages....\n!! Please make sure no used channels are muted !!"
    sudo apt-get install -y linux-sound-base alsa-base alsa-utils > /dev/null 2>&1
    sudo alsamixer
}

function Installnfscommon()
{
    showInfo "Installing ubuntu package nfs-common (kernel based NFS clinet support)"
    sudo apt-get install -y nfs-common > /dev/null 2>&1
}

function installLirc()
{
    clear
    echo ""
    echo "Installing lirc..."
    echo ""
    echo "------------------"
    echo ""
    
	sudo apt-get -y install lirc
	
	if [ "$?" == "0" ]; then
        showInfo "Lirc successfully installed"
    else
        showError "Lirc could not be installed (error code: $?)"
    fi
}

function allowRemoteWakeup()
{
    showInfo "Allowing for remote wakeup (won't work for all remotes)..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	handleFileBackup "$REMOTE_WAKEUP_RULES_FILE" 1 1
	download $DOWNLOAD_URL"remote_wakeup_rules"
	
	if [ -e $TEMP_DIRECTORY"remote_wakeup_rules" ]; then
	    sudo mv $TEMP_DIRECTORY"remote_wakeup_rules" "$REMOTE_WAKEUP_RULES_FILE" > /dev/null 2>&1
	    showInfo "Remote wakeup rules successfully applied"
	else
	    showError "Remote wakeup rules could not be downloaded"
	fi
}

function installTvHeadend()
{
    showInfo "Adding jabbors hts-stable PPA..."
	addRepository "$HTS_TVHEADEND_PPA"

    clear
    echo ""
    echo "Installing tvheadend..."
    echo ""
    echo "------------------"
    echo ""

    sudo apt-get -y install tvheadend
    
    if [ "$?" == "0" ]; then
        showInfo "TvHeadend successfully installed"
    else
        showError "TvHeadend could not be installed (error code: $?)"
    fi
}

function installOscam()
{
    showInfo "Adding oscam PPA..."
    addRepository "$OSCAM_PPA"

    showInfo "Installing oscam..."
    IS_INSTALLED=$(aptInstall oscam-svn)
}

function installXbmc()
{
    showInfo "Installing KODI..."
    IS_INSTALLED=$(aptInstall kodi)
}

function installXbmcAddonRepositoriesInstaller()
{
    showInfo "Installing Addon Repositories Installer addon..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	download $DOWNLOAD_URL"plugin.program.repo.installer-1.0.5.tar.gz"
    createDirectory "$KODI_ADDONS_DIR" 0 0

    if [ -e $TEMP_DIRECTORY"plugin.program.repo.installer-1.0.5.tar.gz" ]; then
        tar -xvzf $TEMP_DIRECTORY"plugin.program.repo.installer-1.0.5.tar.gz" -C "$KODI_ADDONS_DIR" > /dev/null 2>&1
        
        if [ "$?" == "0" ]; then
	        showInfo "Addon Repositories Installer addon successfully installed"
	    else
	        showError "Addon Repositories Installer addon could not be installed (error code: $?)"
	    fi
    else
	    showError "Addon Repositories Installer addon could not be downloaded"
    fi
}

function configureAtiDriver()
{
    sudo aticonfig --initial -f > /dev/null 2>&1
    sudo aticonfig --sync-vsync=on > /dev/null 2>&1
    sudo aticonfig --set-pcs-u32=MCIL,HWUVD_H264Level51Support,1 > /dev/null 2>&1
}

function ChooseATIDriver()
{
         cmd=(dialog --title "Radeon-OSS drivers" \
                     --backtitle "$SCRIPT_TITLE" \
             --radiolist "It seems you are running ubuntu 13.10. You may install updated radeon oss drivers with VDPAU support. this allows for HD audio amung other things. This is the new default for Gotham and XVBA is depreciated. bottom line. this is what you want." 
             15 $DIALOG_WIDTH 6)
        
        options=(1 "Yes- install radon-OSS (will install 3.13 kernel)" on
                 2 "No - Keep old fglrx drivers (NOT RECOMENDED)" off)
         
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

         case ${choice//\"/} in
             1)
                     InstallRadeonOSS
                 ;;
             2)
                     VIDEO_DRIVER="fglrx"
                 ;;
             *)
                     ChooseATIDriver
                 ;;
         esac
}

function InstallRadeonOSS()
{
    VIDEO_DRIVER="xserver-xorg-video-ati"
    if [ ${DISTRIB_RELEASE//[^[:digit:]]} -ge 1404 ]; then
        showinfo "installing mesa VDPAU packages..."
        sudo apt-get install -y mesa-vdpau-drivers vdpauinfo
        showinfo "Radeon OSS VDPAU install completed"
    else
        showInfo "Adding Wsnsprix MESA PPA..."
        IS_ADDED=$(addRepository "$MESA_PPA")
        sudo apt-get update
        sudo apt-get dist-upgrade
        showinfo "installing reguired mesa patches..."
        sudo apt-get install -y libg3dvl-mesa vdpauinfo linux-firmware
        showinfo "Mesa patches installation complete"
        mkdir -p ~/kernel
        cd ~/kernel
        showinfo "Downloading and installing 3.13 kernel (may take awhile)..."
        wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.13.5-trusty/linux-headers-3.13.5-031305-generic_3.13.5-031305.201402221823_amd64.deb http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.13.5-trusty/linux-headers-3.13.5-031305_3.13.5-031305.201402221823_all.deb http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.13.5-trusty/linux-image-3.13.5-031305-generic_3.13.5-031305.201402221823_amd64.deb
        sudo dpkg -i *3.13.5*deb
        sudo rm -rf ~/kernel
        showinfo "kernel Installation Complete, Radeon OSS VDPAU install completed"
    fi
}

function disbaleAtiUnderscan()
{
	sudo kill $(pidof X) > /dev/null 2>&1
	sudo aticonfig --set-pcs-val=MCIL,DigitalHDTVDefaultUnderscan,0 > /dev/null 2>&1
    showInfo "Underscan successfully disabled"
}

function enableAtiUnderscan()
{
	sudo kill $(pidof X) > /dev/null 2>&1
	sudo aticonfig --set-pcs-val=MCIL,DigitalHDTVDefaultUnderscan,1 > /dev/null 2>&1
    showInfo "Underscan successfully enabled"
}

function addXswatPpa()
{
    showInfo "Adding x-swat/x-updates ppa (“Ubuntu-X” team).."
	IS_ADDED=$(addRepository "$XSWAT_PPA")
}

function InstallLTSEnablementStack()
{
     if [ "$DISTRIB_RELEASE" == "12.04" ]; then
         cmd=(dialog --title "LTS Enablement Stack (LTS Backports)" \
                     --backtitle "$SCRIPT_TITLE" \
             --radiolist "Enable Ubuntu's LTS Enablement stack to update to 12.04.3. The updates include the 3.8 kernel as well as a lot of updates to Xorg. On a non-minimal install these would be selected by default. Do you have to install/enable this?" 
             15 $DIALOG_WIDTH 6)
        
        options=(1 "No - keep 3.2.xx kernel (default)" on
                 2 "Yes - Install (recomended)" off)
         
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

         case ${choice//\"/} in
             1)
                     #do nothing
                 ;;
             2)
                     LTSEnablementStack
                 ;;
             *)
                     InstallLTSEnablementStack
                 ;;
         esac
     fi
}

function LTSEnablementStack()
{
showInfo "Installing ubuntu LTS Enablement Stack..."
sudo apt-get install --install-recommends -y linux-generic-lts-raring xserver-xorg-lts-raring libgl1-mesa-glx-lts-raring > /dev/null 2>&1
# HACK: dpkg is still processsing during next functions, allow some time to settle
sleep 2
showInfo "ubuntu LTS Enablement Stack install completed..."
#sleep again to make sure dpkg is freed for next function
sleep 3
}

function selectNvidiaDriver()
{
    cmd=(dialog --title "Choose which nvidia driver version to install (required)" \
                --backtitle "$SCRIPT_TITLE" \
        --radiolist "Some driver versions play nicely with different cards, Please choose one!" 
        15 $DIALOG_WIDTH 6)
        
   options=(1 "304.88 - ubuntu LTS default (default)" on
            2 "319.xx - Shipped with OpenELEC" off
            3 "331.xx - latest (will install additional x-swat ppa)" off)
         
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    case ${choice//\"/} in
        1)
                VIDEO_DRIVER="nvidia-current"
            ;;
        2)
                VIDEO_DRIVER="nvidia-319-updates"
            ;;
        3)
                addXswatPpa
                VIDEO_DRIVER="nvidia-331"
            ;;
        *)
                selectNvidiaDriver
            ;;
    esac
}

function installVideoDriver()
{
    if [[ $GFX_CARD == NVIDIA ]]; then
        selectNvidiaDriver
    elif [[ $GFX_CARD == ATI ]] || [[ $GFX_CARD == AMD ]] || [[ $GFX_CARD == ADVANCED ]]; then
        if [ ${DISTRIB_RELEASE//[^[:digit:]]} -ge 1310 ]; then
            ChooseATIDriver
            else
            VIDEO_DRIVER="fglrx"
            fi
    elif [[ $GFX_CARD == INTEL ]] || [[ $GFX_CARD == VMWARE ]]; then
        VIDEO_DRIVER="i965-va-driver"
    elif [[ $GFX_CARD == INNOTEK ]]; then
        if [ "$(isModuleLoaded vboxvideo)" == "0" ]; then
            showDialog "vboxvideo module not loaded, install guest additions to improve video performance"
            trap control_c SIGINT
        fi
        VIDEO_DRIVER=""
    else
        cleanUp
        clear
        echo ""
        echo "$(tput setaf 1)$(tput bold)Installation aborted...$(tput sgr0)" 
        echo "$(tput setaf 1)Only NVIDIA, ATI/AMD or INTEL videocards are supported. Please install a compatible videocard and run the script again.$(tput sgr0)"
        echo ""
        echo "$(tput setaf 1)You have a $GFX_CARD videocard.$(tput sgr0)"
        echo ""
        exit
    fi

    showInfo "Installing $GFX_CARD video drivers (may take a while)..."
    IS_INSTALLED=$(aptInstall $VIDEO_DRIVER)

    if [ "IS_INSTALLED=$(isPackageInstalled $VIDEO_DRIVER) == 1" ]; then
        if [ "$GFX_CARD" == "ATI" ] || [ "$GFX_CARD" == "AMD" ] || [ "$GFX_CARD" == "ADVANCED" ]; then
            configureAtiDriver

            dialog --title "Disable underscan" \
                --backtitle "$SCRIPT_TITLE" \
                --yesno "Do you want to disable underscan (removes black borders)? Do this only if you're sure you need it!" 7 $DIALOG_WIDTH

            RESPONSE=$?
            case ${RESPONSE//\"/} in
                0) 
                    disbaleAtiUnderscan
                    ;;
                1) 
                    enableAtiUnderscan
                    ;;
                255) 
                    showInfo "ATI underscan configuration skipped"
                    ;;
            esac
        fi
        
        showInfo "$GFX_CARD video drivers successfully installed and configured"
    fi
}

function installAutomaticDistUpgrade()
{
    showInfo "Enabling automatic system upgrade..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	download $DOWNLOAD_URL"dist_upgrade.sh"
	IS_MOVED=$(move $TEMP_DIRECTORY"dist_upgrade.sh" "$DIST_UPGRADE_FILE" 1)
	
	if [ "$IS_MOVED" == "1" ]; then
	    IS_INSTALLED=$(aptInstall cron)
	    sudo chmod +x "$DIST_UPGRADE_FILE" > /dev/null 2>&1
	    handleFileBackup "$CRONTAB_FILE" 1
	    appendToFile "$CRONTAB_FILE" "0 */4  * * * root  $DIST_UPGRADE_FILE >> $DIST_UPGRADE_LOG_FILE"
	else
	    showError "Automatic system upgrade interval could not be enabled"
	fi
}

function removeAutorunFiles()
{
    if [ -e "$KODI_INIT_FILE" ]; then
        showInfo "Removing existing autorun script..."
        sudo update-rc.d kodi remove > /dev/null 2>&1
        sudo rm "$KODI_INIT_FILE" > /dev/null 2>&1

        if [ -e "$KODI_INIT_CONF_FILE" ]; then
		    sudo rm "$KODI_INIT_CONF_FILE" > /dev/null 2>&1
	    fi
	    
	    if [ -e "$KODI_CUSTOM_EXEC" ]; then
	        sudo rm "$KODI_CUSTOM_EXEC" > /dev/null 2>&1
	    fi
	    
	    if [ -e "$KODI_XSESSION_FILE" ]; then
	        sudo rm "$KODI_XSESSION_FILE" > /dev/null 2>&1
	    fi
	    
	    showInfo "Old autorun script successfully removed"
    fi
}

function installXbmcUpstartScript()
{
    removeAutorunFiles
    showInfo "Installing KODI upstart autorun support..."
    createDirectory "$TEMP_DIRECTORY" 1 0
	download $DOWNLOAD_URL"kodi_upstart_script_2"

	if [ -e $TEMP_DIRECTORY"kodi_upstart_script_2" ]; then
	    IS_MOVED=$(move $TEMP_DIRECTORY"kodi_upstart_script_2" "$KODI_INIT_CONF_FILE")

	    if [ "$IS_MOVED" == "1" ]; then
	        sudo ln -s "$UPSTART_JOB_FILE" "$KODI_INIT_FILE" > /dev/null 2>&1
	    else
	        showError "KODI upstart configuration failed"
	    fi
	else
	    showError "Download of KODI upstart configuration file failed"
	fi
}

function installNyxBoardKeymap()
{
    showInfo "Applying Pulse-Eight Motorola NYXboard advanced keymap..."
	createDirectory "$TEMP_DIRECTORY" 1 0
	download $DOWNLOAD_URL"nyxboard.tar.gz"
    createDirectory "$KODI_KEYMAPS_DIR" 0 0

    if [ -e $KODI_KEYMAPS_DIR"keyboard.xml" ]; then
        handleFileBackup $KODI_KEYMAPS_DIR"keyboard.xml" 0 1
    fi

    if [ -e $TEMP_DIRECTORY"nyxboard.tar.gz" ]; then
        tar -xvzf $TEMP_DIRECTORY"nyxboard.tar.gz" -C "$KODI_KEYMAPS_DIR" > /dev/null 2>&1
        
        if [ "$?" == "0" ]; then
	        showInfo "Pulse-Eight Motorola NYXboard advanced keymap successfully applied"
	    else
	        showError "Pulse-Eight Motorola NYXboard advanced keymap could not be applied (error code: $?)"
	    fi
    else
	    showError "Pulse-Eight Motorola NYXboard advanced keymap could not be downloaded"
    fi
}

function installXbmcBootScreen()
{
    showInfo "Installing KODI boot screen (please be patient)..."
    sudo apt-get install -y plymouth-label v86d > /dev/null
    createDirectory "$TEMP_DIRECTORY" 1 0
    download $DOWNLOAD_URL"plymouth-theme-kodi-logo.deb"
    
    if [ -e $TEMP_DIRECTORY"plymouth-theme-kodi-logo.deb" ]; then
        sudo dpkg -i $TEMP_DIRECTORY"plymouth-theme-kodi-logo.deb" > /dev/null 2>&1
        update-alternatives --install /lib/plymouth/themes/default.plymouth default.plymouth /lib/plymouth/themes/kodi-logo/kodi-logo.plymouth 100 > /dev/null 2>&1
        handleFileBackup "$INITRAMFS_SPLASH_FILE" 1 1
        createFile "$INITRAMFS_SPLASH_FILE" 1 1
        appendToFile "$INITRAMFS_SPLASH_FILE" "FRAMEBUFFER=y"
        showInfo "KODI boot screen successfully installed"
    else
        showError "Download of KODI boot screen package failed"
    fi
}

function applyScreenResolution()
{
    RESOLUTION="$1"
    
    showInfo "Applying bootscreen resolution (will take a minute or so)..."
    handleFileBackup "$GRUB_HEADER_FILE" 1 0
    sudo sed -i '/gfxmode=/ a\  set gfxpayload=keep' "$GRUB_HEADER_FILE" > /dev/null 2>&1
    GRUB_CONFIG="nomodeset usbcore.autosuspend=-1 video=uvesafb:mode_option=$RESOLUTION-24,mtrr=3,scroll=ywrap"
    
    if [[ $GFX_CARD == INTEL ]]; then
        GRUB_CONFIG="usbcore.autosuspend=-1 video=uvesafb:mode_option=$RESOLUTION-24,mtrr=3,scroll=ywrap"
    fi
    if [[ $RADEON_OSS == 1 ]]; then
        GRUB_CONFIG="usbcore.autosuspend=-1 video=uvesafb:mode_option=$RESOLUTION-24,mtrr=3,scroll=ywrap radeon.audio=1 radeon.dpm=1 quiet splash"
    fi
    
    handleFileBackup "$GRUB_CONFIG_FILE" 1 0
    appendToFile "$GRUB_CONFIG_FILE" "GRUB_CMDLINE_LINUX=\"$GRUB_CONFIG\""
    appendToFile "$GRUB_CONFIG_FILE" "GRUB_GFXMODE=$RESOLUTION"
    appendToFile "$GRUB_CONFIG_FILE" "GRUB_RECORDFAIL_TIMEOUT=0"
    
    handleFileBackup "$INITRAMFS_MODULES_FILE" 1 0
    appendToFile "$INITRAMFS_MODULES_FILE" "uvesafb mode_option=$RESOLUTION-24 mtrr=3 scroll=ywrap"
    
    sudo update-grub > /dev/null 2>&1
    sudo update-initramfs -u > /dev/null
    
    if [ "$?" == "0" ]; then
        showInfo "Bootscreen resolution successfully applied"
    else
        showError "Bootscreen resolution could not be applied"
    fi
}

function installLmSensors()
{
    showInfo "Installing temperature monitoring package (will apply all defaults)..."
    aptInstall lm-sensors
    sudo yes "" | sensors-detect > /dev/null 2>&1

    if [ ! -e "$KODI_ADVANCEDSETTINGS_FILE" ]; then
	    createDirectory "$TEMP_DIRECTORY" 1 0
	    download $DOWNLOAD_URL"temperature_monitoring.xml"
	    createDirectory "$KODI_USERDATA_DIR" 0 0
	    IS_MOVED=$(move $TEMP_DIRECTORY"temperature_monitoring.xml" "$KODI_ADVANCEDSETTINGS_FILE")

	    if [ "$IS_MOVED" == "1" ]; then
            showInfo "Temperature monitoring successfully enabled in KODI"
        else
            showError "Temperature monitoring could not be enabled in KODI"
        fi
    fi
    
    showInfo "Temperature monitoring successfully configured"
}

function reconfigureXServer()
{
    showInfo "Configuring X-server..."
    handleFileBackup "$XWRAPPER_FILE" 1
    createFile "$XWRAPPER_FILE" 1 1
	appendToFile "$XWRAPPER_FILE" "allowed_users=anybody"
	showInfo "X-server successfully configured"
}

function selectXbmcTweaks()
{
    cmd=(dialog --title "Optional KODI tweaks and additions" 
        --backtitle "$SCRIPT_TITLE" 
        --checklist "Plese select to install or apply:" 
        15 $DIALOG_WIDTH 6)
        
   options=(1 "Enable temperature monitoring (confirm with ENTER)" on
            2 "Install Addon Repositories Installer addon" on
            3 "Apply improved Pulse-Eight Motorola NYXboard keymap" off)
            
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    for choice in $choices
    do
        case ${choice//\"/} in
            1)
                installLmSensors
                ;;
            2)
                installXbmcAddonRepositoriesInstaller 
                ;;
            3)
                installNyxBoardKeymap 
                ;;
        esac
    done
}

function selectScreenResolution()
{
    cmd=(dialog --backtitle "Select bootscreen resolution (required)"
        --radiolist "Please select your screen resolution, or the one sligtly lower then it can handle if an exact match isn't availabel:" 
        15 $DIALOG_WIDTH 6)
        
    options=(1 "720 x 480 (NTSC)" off
            2 "720 x 576 (PAL)" off
            3 "1280 x 720 (HD Ready)" on
            4 "1366 x 768 (HD Ready)" off
            5 "1920 x 1080 (Full HD)" off)
         
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    case ${choice//\"/} in
        1)
            applyScreenResolution "720x480"
            ;;
        2)
            applyScreenResolution "720x576"
            ;;
        3)
            applyScreenResolution "1280x720"
            ;;
        4)
            applyScreenResolution "1366x768"
            ;;
        5)
            applyScreenResolution "1920x1080"
            ;;
        *)
            selectScreenResolution
            ;;
    esac
}

function selectAdditionalPackages()
{
    cmd=(dialog --title "Other optional packages and features" 
        --backtitle "$SCRIPT_TITLE" 
        --checklist "Plese select to install:" 
        15 $DIALOG_WIDTH 6)
        
    options=(1 "Lirc (IR remote support)" on
            2 "Hts tvheadend (live TV backend)" off
            3 "Oscam (live HDTV decryption tool)" off
            4 "Automatic upgrades (every 4 hours)" off
            5 "OS-based NFS Support (nfs-common)" off)
            
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

    for choice in $choices
    do
        case ${choice//\"/} in
            1)
                installLirc
                ;;
            2)
                installTvHeadend 
                ;;
            3)
                installOscam 
                ;;
            4)
                installAutomaticDistUpgrade
                ;;
            5)
                Installnfscommon
                ;;
        esac
    done
}

function optimizeInstallation()
{
    showInfo "Optimizing installation..."

    sudo echo "none /tmp tmpfs defaults 0 0" >> /etc/fstab

    sudo service apparmor stop > /dev/null &2>1
    sleep 2
    sudo service apparmor teardown > /dev/null &2>1
    sleep 2
    sudo update-rc.d -f apparmor remove > /dev/null &2>1	
    sleep 2
    sudo apt-get purge apparmor -y > /dev/null &2>1
    sleep 3
    
    createDirectory "$TEMP_DIRECTORY" 1 0
	handleFileBackup $RSYSLOG_FILE 0 1
	download $DOWNLOAD_URL"rsyslog.conf"
	move $TEMP_DIRECTORY"rsyslog.conf" "$RSYSLOG_FILE" 1
    
    handleFileBackup "$SYSCTL_CONF_FILE" 1 0
    createFile "$SYSCTL_CONF_FILE" 1 0
    appendToFile "$SYSCTL_CONF_FILE" "dev.cdrom.lock=0"
    appendToFile "$SYSCTL_CONF_FILE" "vm.swappiness=10"
}

function cleanUp()
{
    showInfo "Cleaning up..."
	sudo apt-get -y autoremove > /dev/null 2>&1
        sleep 1
	sudo apt-get -y autoclean > /dev/null 2>&1
        sleep 1
	sudo apt-get -y clean > /dev/null 2>&1
        sleep 1
        sudo chown -R kodi:kodi /home/kodi/.kodi > /dev/null 2>&1
        showInfo "fixed permissions for kodi userdata folder"
	
	if [ -e "$TEMP_DIRECTORY" ]; then
	    sudo rm -R "$TEMP_DIRECTORY" > /dev/null 2>&1
	fi
}

function rebootMachine()
{
    showInfo "Reboot system..."
	dialog --title "Installation complete" \
		--backtitle "$SCRIPT_TITLE" \
		--yesno "Do you want to reboot now?" 7 $DIALOG_WIDTH

	case $? in
        0)
            showInfo "Installation complete. Rebooting..."
            clear
            echo ""
            echo "Installation complete. Rebooting..."
            echo ""
            sudo reboot > /dev/null 2>&1
	        ;;
	    1) 
	        showInfo "Installation complete. Not rebooting."
            quit
	        ;;
	    255) 
	        showInfo "Installation complete. Not rebooting."
	        quit
	        ;;
	esac
}

function quit()
{
	clear
	exit
}

control_c()
{
    cleanUp
    echo "Installation aborted..."
    quit
}

## ------- END functions -------

clear

createFile "$LOG_FILE" 0 1

echo ""
installDependencies
echo "Loading installer..."
showDialog "Welcome to the KODI minimal installation script. Some parts may take a while to install depending on your internet connection speed.\n\nPlease be patient..."
trap control_c SIGINT

fixLocaleBug
fixUsbAutomount
applyXbmcNiceLevelPermissions
addUserToRequiredGroups
addXbmcPpa
distUpgrade
installVideoDriver
installXinit
installXbmc
installXbmcUpstartScript
installXbmcBootScreen
selectScreenResolution
reconfigureXServer
installPowerManagement
installAudio
selectXbmcTweaks
selectAdditionalPackages
InstallLTSEnablementStack
allowRemoteWakeup
optimizeInstallation
cleanUp
rebootMachine
