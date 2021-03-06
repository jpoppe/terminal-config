#!/bin/bash
STARTPWD=$(pwd)

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`

if [ -z $GIT_REPO ]; then
    GIT_REPO="https://raw.githubusercontent.com/j-maynard/terminal-config/master"
fi

# Define colors and styles
normal="\033[0m"
bold="\033[1m"
green="\e[32m"
red="\e[31m"
yellow="\e[93m"

set_username() {
    if [ -z $SUDO_USER ]; then
        USERNAME=$USER
        WSL_USER=$USER
    else
        USERNAME=$SUDO_USER
    fi
    if [ $USERNAME == "root" ]; then
        if [[ -v WSLENV && ! -v WSL_USER ]]; then
            show_msg "WSL Username not set... Exiting!"
            exec > /dev/tty
            usage
            exit 1
        fi
        USER_PATH="/root"
    else
        USER_PATH="/home/$USER"
    fi
    if [ ! -v WSL_USER ]; then
        WSL_USER=$USERNAME
    fi
}

usage() {
    echo -e "Usage:"
    echo -e "  ${bold}${red}-s  --streaming${normal}              Install OBS studio as well as v4l2loopback for steaming"
    echo -e "  ${bold}${red}-c  --commandline-only${normal}       Install only commandline tools (no snaps, no chrome, etc...)"
    echo -e "  ${bold}${red}-w  --wsl-user [username]${normal}    Sets the Windows username which runs WSL.  This is used to find the windows"
    echo -e "                               users home directory. If not specified it matches it to the linux username."
    echo -e "                               If you run this script as root then you ${bold}MUST${normal} specify this."
    echo -e "  ${bold}${red}-V  --verbose${normal}                Shows command output for debugging"
    echo -e "  ${bold}${red}-v  --version${normal}                Shows version details and exit"
    echo -e "  ${bold}${red}-h  --help${normal}                   Shows this usage message and exit"
}

version() {
    echo -e "Ubuntu Setup Script Version 0.5"
    echo -e "(c) Jamie Maynard 2020"
}

show_msg() {
    echo -e $1 > /dev/tty
}

apt_update() {
    show_msg "Updating the system..."
    sudo apt-get update
    sudo apt-get upgrade -y
}

pkcon_update() {
    show_msg "Updating the system..."
    sudo apt-get update
    sudo pkcon update -y --allow-downgrades
}

apt_install() {
    show_msg "Installing from apt... "

    apt_pkgs=( "git" "curl" "zsh"  "python3.8-dev" "python3-pip" 
        "build-essential" "jed" "htop" "links" "lynx" "tree" "tmux" 
        "openjdk-11-jdk" "openjdk-8-jdk" "maven" "vim" "vim-nox"
        "vim-scripts" "most" "ruby-dev" "scdaemon" "pinentry-tty"
        "pinentry-curses" "libxml2-utils" "apt-transport-https"
	"neovim" "libgconf-2-4" "libappindicator1" "libc++1" "clamav" )

    x_apt_pkgs=( "idle-python3.8" "vim-gtk3" "pinentry-qt" "libappindicator3-1"
        "flatpak" "gnome-keyring" "neovim" "materia-gtk-theme" "gtk2-engines-murrine"
	"gtk2-engines-pixbuf" "lm-sensors" "nvme-cli" "conky-all" )

    neon_pkgs=( "openjdk-11-jdk" "default-jdk" "wget" "fonts-liberation" )

    kde_pkgs=( "kmail" "latte-dock" "umbrello" "kdegames" "kaddressbook"
        "akonadi-backend-postgresql" "akonadi-backend-sqlite" "kleopatra")
    
    streaming_apt_pkgs=( "ffmpeg" "v4l2loopback-dkms" "v4l2loopback-utils" )

    for pkg in ${apt_pkgs[@]}; do
	PKGS="${PKGS} ${pkg} "
    done
    if [[ $COMMANDLINE_ONLY == "false" ]]; then
        for pkg in ${x_apt_pkgs[@]}; do
            PKGS="${PKGS} ${pkg} "
        done
        if plasmashell --version >/dev/null 2>&1; then
            for pkg in ${kde_pkgs[@]}; do
                PKGS="${PKGS} ${pkg} "
            done
        fi
        if [[ $NEON == "true" ]]; then
            for pkg in ${neon_pkgs[@]}; do
                PKGS="${PKGS} ${pkg} "
            done
        fi
	sudo usermod -a -G disk `whoami`
	sudo usermod -a -G users `whoami`
    fi

    if [[ $STREAMING == "true" ]]; then
        for pkg in ${streaming_apt_pkgs[@]}; do
            PKGS="${PKGS} ${pkg} "
        done
    fi

    SORTED_PKGS=($(for a in "${PKGS[@]}"; do echo "$a "; done | sort))
    col=0
    for pkg in ${SORTED_PKGS[@]}; do
        if [[ $col == '3' ]]; then
            pkg_out="${pkg_out}${pkg}\n"
            col=0
        else
            pkg_out="${pkg_out}${pkg} | "
            col=$(expr $col + 1)
        fi
    done

    show_msg "Installing the following packages using apt:"
    echo -e ${pkg_out[@]} | column -t -s "|" > /dev/tty
    if [ $VERBOSE == 'true' ]; then
	    show_msg "sudo apt-get install ${PKGS[@]}"
    fi
    sudo apt-get install -y ${PKGS[@]}
}

setup_openrazer() {
    if lsusb |grep 1532 > /dev/null 2>&1; then
        show_msg "Razer Hardware Detected... Installing OpenRazer..."
        sudo add-apt-repository -y ppa:openrazer/stable
        sudo apt-get install -y openrazer-meta

        if [[ $COMMANDLINE_ONLY == "false" ]]; then
            # Add RazerGenie Repo
            echo 'deb http://download.opensuse.org/repositories/hardware:/razer/xUbuntu_20.04/ /' | sudo tee /etc/apt/sources.list.d/hardware-razer.list
            curl -LSso /tmp/razergenie.key https://download.opensuse.org/repositories/hardware:/razer/xUbuntu_20.04/Release.key
            sudo apt-key add /tmp/razergenie.key
            # Add Polychromatic Repo
            sudo add-apt-repository -y ppa:polychromatic/stable
            # Install Both
            sudo apt-get update
            sudo apt-get install -y polychromatic razergenie
        fi
    fi
}

install_kvantum() {
    if which plasmashell > /dev/null; then
        sudo add-apt-repository -y ppa:papirus/papirus
        sudo apt-get update
        sudo apt-get install -y qt5-style-kvantum qt5-style-kvantum-themes
    fi
}

setup_obs() {
    sudo ubuntu-drivers autoinstall
    sudo add-apt-repository -y ppa:obsproject/obs-studio
    sudo apt-get install -y obs-studio
    sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="OBS Cam" exclusive_caps=1
    echo 'v4l2loopback' | sudo tee -a /etc/modules 
    echo 'options v4l2loopback devices=1 video_nr=10 card_label="OBS Cam" exclusive_caps=1' | sudo tee - /etc/modprobe.d/v4l2loopback.conf
    wget -q -O /tmp/obs-v4l2sink.deb https://github.com/CatxFish/obs-v4l2sink/releases/download/0.1.0/obs-v4l2sink.deb
    sudo dpkg -i /tmp/obs-v4l2sink.deb
    if lsusb |grep 0fd9:006d > /dev/null; then
        setup_streamdeck
    else
        show_msg "If this system will be used with streamdeck you'll"
        show_msg "need to run the streamdeck setup script"
    fi
    install_steam
    install_minecraft
}

setup_streamdeck() {
    show_msg "Installing streamdeck libraries..."
    sudo apt-get install -y qt5-default libhidapi-hidraw0 libudev-dev libusb-1.0-0-dev python3-pip
    show_msg "Adding udev rules and reloading"
    sudo usermod -a -G plugdev `whoami`

    sudo tee /etc/udev/rules.d/99-streamdeck.rules << EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", MODE:="666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", MODE:="666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE:="666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", MODE:="666", GROUP="plugdev"
EOF

    sudo udevadm control --reload-rules

    show_msg "Unplug and replug in device for the new udev rules to take effect"
    show_msg "Installing streamdeck_ui..."
    pip3 install --user streamdeck_ui
    if [ $? == 0 ]; then
        show_msg "StreamDeck-UI Installed"
    else
        show_msg "Something went wrong installing StreamDeck-Ui"
    fi
}

install_steam() {
    sudo apt-get install -y zenity zenity-common
    wget -O /tmp/steam.deb https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb
    sudo dpkg -i /tmp/steam.deb
}

install_minecraft() {
    wget -O /tmp/minecraft.deb https://launcher.mojang.com/download/Minecraft.deb
    sudo dpkg -i /tmp/minecraft.deb
}

install_inkscape() {
    sudo add-apt-repository -y ppa:inkscape.dev/stable
    sudo apt-get update
    sudo apt-get install -y inkscape
}

install_1password() {
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22 > /dev/null 2>&1
    sudo add-apt-repository 'deb [arch=amd64] https://onepassword.s3.amazonaws.com/linux/debian edge main'
    sudo apt-get install -y 1password
}

setup_flatpak() {
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub org.gnome.Platform//3.38
    sudo flatpak install -y flathub org.gtk.Gtk3theme.Breeze-Dark
    sudo flatpak install -y flathub org.gnome.Geary
    sudo flatpak install -y flathub org.gtk.Gtk3theme.Materia-dark-compact
    sudo flatpak install -y flathub org.kde.kontact
}

install_layan() {
    cd /tmp
    git clone ${GITQUITET} https://github.com/vinceliuice/Layan-gtk-theme.git
    cd Layan-gtk-theme
    /tmp/Layan-gtk-theme/install.sh
    if [ $? ]; then
    	echo "Layan GTK Theme successfully installed"
	cd /tmp
	rm -rf /tmp/Layan-gtk-theme
    fi
}

install_docker() {
    show_msg "Installing Docker Community Edition..."
    curl -fsSLo /tmp/docker.key https://download.docker.com/linux/ubuntu/gpg
    sudo apt-key add /tmp/docker.key && rm /tmp/docker.key
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    if [ $? ]; then
        show_msg "Docker installed successfully"
    fi
    sudo usermod -a -G docker $USERNAME
    show_msg "Installing docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    if which docker-compose > /dev/null; then
        show_msg "Docker Compose installed successfully..."
    else
        show_msg "Docker Compose install failed... You may need to add /usr/local/bin to your path"
    fi
}

install_virtualbox() {
    show_msg "Installing Oracle Virtual Box..."
    dist=$(lsb_release -c | cut -d':' -f 2 | tr -d '[:space:]')
    echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $dist contrib" | sudo tee -a /etc/apt/sources.list
    curl -Ss https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo apt-key add -
    sudo apt-get update
    pkg=$(apt-cache search virtualbox | grep Oracle |sort -r |head -n1 |cut -d ' ' -f1)
    sudo apt-get install -y $pkg
}

snap_install() {
    show_msg "Installing the following packages from snap:"
    show_msg "1Password"
    show_msg "Authy"
    show_msg "Insomnia"
    show_msg "Slack"
    show_msg "ncspot"
    show_msg "yq"

    if ! which authy > /dev/null; then
        sudo snap install authy --beta
    fi

    if ! which slack > /dev/null; then
        sudo snap install slack --classic
    fi
    
    if ! which insomnia > /dev/null; then
        sudo snap install insomnia
    fi

    if ! which authy > /dev/null; then
        sudo snap install authy --beta
    fi

    if ! which ncspot > /dev/null; then
        sudo snap install ncspot
    fi
    
    if ! which yq > /dev/null; then
        sudo snap install yq
    fi

    if ! which 1password > /dev/null; then
	sudo snap install 1password --edge
    fi
}

install_chrome() {
    if ! which google-chrome > /dev/null; then
        show_msg "Installing Google Chrome (Latest)..."
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        if [ ! -f "google-chrome-stable_current_amd64.deb" ]; then
            show_msg "${red}Failed to download Google Chrome... ${normal}${green}Skipping install...${normal}"
            return
        fi
        sudo dpkg -i google-chrome-stable_current_amd64.deb
        if [ $? == 0 ]; then
            rm google-chrome-stable_current_amd64.deb
        else
            show_msg "Failed to install chrome"
        fi
    fi
}

install_spotify() {
    show_msg "Installing Spotify Client..."
    if ! which spotify > /dev/null; then
        curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | sudo apt-key add - 
        echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
        sudo apt-get update && sudo apt-get install spotify-client
        if [[ $4K == "true" ]]; then
            sed "s/Exec=spotify %U/Exec=spotify --force-device-scale-factor=1.75 %U/" /usr/local/share/applications/spotify.desktop | sudo tee /usr/local/share/applications/spotify.desktop
        fi
    fi
}

install_1password() {
    if ! which 1password > /dev/null; then
        show_msg "Installing 1password (Beta)..."
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
        sudo add-apt-repository 'deb [arch=amd64] https://onepassword.s3.amazonaws.com/linux/debian edge main'
        sudo apt install 1password
        if [ $? != 0 ]; then
            show_msg "Failed to install 1password"
        fi
    fi 
}

install_discord() {
    if ! which discord; then
        show_msg "Installing Discord (Latest)..."
        sudo apt install libappindicator1 libc++1 
        wget -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
        sudo dpkg -i /tmp/discord.deb
        if which discord >/dev/null; then
            rm /tmp/discord.deb
        else
            sudo apt-get --fix-broken install
            if which discord >/dev/null; then
                rm /tmp/discord.deb
                show_msg "Discord installed successfully"
            else
                show_msg "Failed to install discord"
            fi
        fi
    fi
}

install_xidel() {
    if ! which xidel; then
        wget -q -O /tmp/xidel_0.9.8-1_amd64.deb https://sourceforge.net/projects/videlibri/files/Xidel/Xidel%200.9.8/xidel_0.9.8-1_amd64.deb/download 
        if ! sudo dpkg -i xidel_0.9.8-1_amd64.deb; then
            show_msg "Failed to install xidel"
        fi
        rm /tmp/xidel_0.9.8-1_amd64.deb
    fi
}

install_lsd() {
    install_xidel
    if which xidel; then
        LSDVER=$(curl -s https://github.com/Peltoche/lsd/tags.atom | xidel -se '//feed/entry[1]/title' - | cut -d' ' -f2)
        case $(uname -m) in
            x86_64)     ARCH=amd64
                        ;;
            armv6l)     ARCH=armv6l
                        ;;
            *)          echo "${red}Can't identify Arch to match to an LSD download.  Arch = $(uname -m)... ${normal}${green}Skipping...${normal}"
                        return
        esac
        show_msg "Installing the latest version of LSD -> version: ${LSDVER}..."
        wget -q -O /tmp/lsd_${LSDVER}_${ARCH}.deb "https://github.com/Peltoche/lsd/releases/download/${LSDVER}/lsd_${LSDVER}_${ARCH}.deb"
        if [ ! -f "lsd_${LSDVER}_${ARCH}.deb" ]; then
            show_msg "${red}Failed to download go... ${normal}${green}Skipping install...${normal}"
            return
        fi
        sudo dpkg -i /tmp/lsd_${LSDVER}_${ARCH}.deb
        if which lsd; then
            rm /tmp/lsd_${LSDVER}_${ARCH}.deb
        else
            show_msg "Failed to install ls replacement lsd"
	fi
    fi
}

install_go() {
    install_xidel
    if which xidel; then
	COUNT=1
        while true; do
		GOVER=$(curl -s https://github.com/golang/go/releases.atom | xidel -se "//feed/entry[$COUNT]/link/@href" - | grep -o '[^/]*$')
		if [[ $GOVER = *beta* ]]; then
			COUNT=$((COUNT+1))
		else
			break
		fi
	done
        if [ -d /usr/local/go ]; then
            if [ -f /usr/local/go/bin/go ]; then
            if [ $(/usr/local/go/bin/go version | cut -d' ' -f3) ==  $GOVER ]; then
                show_msg "${green}Latest Version of Go (${GOVER} is already installed.${normal}  Skipping go install..."
                return
            fi
        fi
        fi
        case $(uname -m) in
            x86_64)     ARCH=amd64
                        ;;
            armv6l)     ARCH=armv6l
                        ;;
            *)          show_msg "${red}Can't identify Arch to match to a Go download.  Arch = $(uname -m)... ${normal}${green}Skipping...${normal}"
                        return
        esac
        show_msg "Installing the latest version of Go -> version: ${GOVER}..."
        wget -q https://dl.google.com/go/${GOVER}.linux-${ARCH}.tar.gz
        if [ ! -f "${GOVER}.linux-${ARCH}.tar.gz" ]; then
            show_msg "${red}Failed to download go... ${normal}${green}Skipping install...${normal}"
            return
        fi
        if [ -d "/usr/local/go" ]; then
            sudo rm -rf /usr/local/go
        fi
        sudo tar -zxf /tmp/${GOVER}.linux-amd64.tar.gz --directory /usr/local/
        rm ${GOVER}.linux-amd64.tar.gz
        if [[ -f "/usr/local/bin/go" ]]; then
            sudo rm /usr/local/bin/go
        fi
        if [[ -f "/usr/local/bin/gofmt" ]]; then
            sudo rm /usr/local/bin/gofmt
        fi
        sudo ln -s /usr/local/go/bin/go /usr/local/bin/go
        sudo ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt
    fi
}

install_antibody() {
	which antibody
	if [ $? != 0 ]; then
	    show_msg "Installing antibody..."
	    curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
	fi
}

change_shell() {
	if [[ $(awk -F: '/${USERNAME}/ {print $7}' /etc/passwd) != "/bin/zsh" ]]; then
	    show_msg "Changing shells to ZSH..."
	    sudo chsh -s /bin/zsh $USERNAME
	fi
}

fix_sddm() {
    if [[ -f "/usr/share/sddm/scripts/Xsetup" ]]; then
        show_msg "SDDM present"
        grep term-config /usr/share/sddm/scripts/Xsetup
        if [ $? != 0 ]; then
            show_msg "Updating SDDM XSetup script..."
            curl -LSs "$GIT_REPO/Xsetup.snippet" | sudo tee -a /usr/share/sddm/scripts/Xsetup
        fi
    fi
}

fix-update-grub() {
	# Install Grub Theme
	# TODO Make own GRUB theme for the Razer Blade	
	t=/tmp/grub2-theme2
	git clone ${GITQUITET} https://github.com/vinceliuice/grub2-themes.git $t
        if /usr/bin/xrandr --query|/usr/bin/grep -A 1 connected|grep -v connected| grep 2160 > /dev/null 2&>1; then
            R4K='-4'
        fi
	sudo $t/install.sh -b -v -w $R4K > /dev/null 2>&1
	sudo $t/install.sh -b -s $R4K > /dev/null 2>&1
	sudo $t/install.sh -b -l $R4K > /dev/null 2>&1
	sudo $t/install.sh -b -t $R4K > /dev/null 2>&1
	rm -rf $t
	# As there is no accurate way to detect Kubuntu from Ubuntu
	# We look for plasmashell instead and then assume its Kubuntu.
	if plasmashell --version >/dev/null 2>&1; then
		cat << EOF | sudo tee - /usr/sbin/update-grub
#!/bin/sh                                                               
set -e                                                                  
grub-mkconfig -o /boot/grub/grub.cfg "\$@"                          
if plasmashell --version >/dev/null 2>&1; then                          
        echo "Looks like Kubuntu... Updating Ubuntu to Kubuntu... " >&2 
        C=/boot/grub/grub.cfg                                           
        chmod +w \$C 
        sed -i 's/ubuntu/kubuntu/' \$C
        sed -i 's/Ubuntu/Kubuntu/' \$C
        chmod -w \$C
fi
EOF
	fi
}

setup_wsl() {
    if [ ! -v WSLENV ]; then
        return
    fi 
    WSL=true
    show_msg "WSL Environment variable present.  Setup WSL specific stuff..."
    sudo apt-get install -y socat
    if [ ! -d "/mnt/c/Users/$WSL_USER" ]; then
        show_msg "${red}Can't match username to directory.  Tried ${bold}'/mnt/c/Users/$WSL_USER'${normal}${red}... Have you set the wsl-user option?${normal}"
        exec > /dev/tty
        usage
        show_msg "${red}Unable to continue.  ${bold}Exiting...${normal}"
        exit 1
    else
        WSL_HOME="/mnt/c/Users/$WSL_USER"
    fi
    exec > /dev/tty
    if [ ! -d "/mnt/c/Program Files (x86)/Gpg4win/bin" ]; then
        echo -e "Please download and install WinGPG from https://www.gpg4win.org/thanks-for-download.html"
        read -p "Once this is done please press any key to continue..."
    fi
    if [ ! -d "/mnt/c/Program Files (x86)/Gpg4win/bin" ]; then
        show_msg "Unable to complete WSL due to missing WinGPG"
        return 1
    fi
    WINGPG_HOME="$WSL_HOME/AppData/Roaming/gnupg"
    mkdir -p $WINGPG_HOME
    if [ ! -f "${WINGPG_HOME}/npiperelay.exe" ]; then
        wget -q -O "${WINGPG_HOME}/npiperelay.exe" https://github.com/NZSmartie/npiperelay/releases/download/v0.1/npiperelay.exe
    fi
    cat << EOF > "${WINGPG_HOME}/gpg-agent.conf"
enable-ssh-support
enable-putty-support
pinentry-program "C:\Program Files (x86)\Gpg4win\bin\pinentry-w32.exe"
default-cache-ttl 60
max-cache-ttl 120
EOF
    /mnt/c/Program\ Files\ \(x86\)/GnuPG/bin/gpg-connect-agent.exe /bye
    curl -LSs https://raw.githubusercontent.com/j-maynard/terminal-config/master/wingpg/create-gpg-agent-lnk.ps1 | sed "s|\$USER=|\$USER=${WSL_USER}|g" > /mnt/c/temp/create-gpg-agent-lnk.ps1
    powershell.exe -ExecutionPolicy Bypass c:\\temp\\create-gpg-agent-lnk.ps1
}

install_con_fonts() {
    if [ -v WSLENV ]; then
        return
    fi
    show_msg "Running console fonts setup script..."
    curl -LSs "$GIT_REPO/console-font-setup.sh" | sudo bash -s - $VARG
}

setup_shims() {
    show_msg "Running jenv/rbenv setup script..."
    curl -LSs "$GIT_REPO/shim-setup.sh" | bash -s - $VARG
}

install_nerd_fonts() {
    if [ $THEME_ONLY == 'true' ]; then
        show_msg "${red}Please make sure you have Nerd Font installed on your system.${normal}"
        return
    fi
    if [[ $COMMANDLINE_ONLY == "true" && ! -v WSLENV ]]; then
        show_msg "${red}Please make sure you have Nerd Font installed on your system.${normal}"
        return
    fi
    if [ -v WSLENV ]; then
        for d in /mnt/c/Users/*; do
            DIR="$d/AppData/Local/Microsoft/Windows/Fonts"
            if [ -d "${DIR}" ]; then
               if ls ${DIR}/*Nerd* &> /dev/null; then 
                    echo -e "${green}${bold}Nerd fonts have been found... Skipping installation...${normal}"
                    return
                fi
            fi
        done
    fi
    git clone $GIT_QUIET https://github.com/ryanoasis/nerd-fonts.git --depth=1 /tmp/fonts
    cd /tmp/fonts
    if [ -v WSLENV ]; then
        cp -r /tmp/fonts/patched-fonts /mnt/c/temp
        powershell.exe -ExecutionPolicy Bypass -File c:/temp/patched-fonts/install.ps1
        rm -rf /mnt/c/temp/patched-fonts
    else
        show_msg "Install NerdFonts..."
        sudo ./install.sh --install-to-system-path
        cd $STARTPWD
        rm -rf /tmp/fonts
    fi
}

################################
# Main Script body starts here #
################################

# Set default options
COMMANDLINE_ONLY=false
STREAMING=false
VERBOSE=false
PRIVATE=false
WSL=false
NEON=false

# Process commandline arguments
while [ "$1" != "" ]; do
    case $1 in
        n | -n | --neon)                NEON=true
                                        ;;
        c | -c | --commandline-only)    COMMANDLINE_ONLY=true
                                    	;;
        w | -w | --wsl-user)            shift
                                        WSL_USER=$1
                                        ;;
	m | -m | --model)		shift
					# Not used for ubuntu.  Skipping
					;;
        s | -s | --streaming)           STREAMING=true
                                        ;;
        V | -V | --verbose)             VERBOSE=true
					VARG="-V"
                                    	;;
        v | -v | --version)             version
                                    	exit 0
                                    	;;
        h | -h | --help)                usage
                                    	exit 0
                                    	;;
        * )                         	echo -e "Unknown option $1...\n"
                                    	usage
                                    	exit 1
                                    	;;
    esac
    shift
done

# Silence output
if [ $VERBOSE == "false" ]; then
    echo "Silencing output"
    GITQUITET="-q"
    exec > /dev/null 
fi

set_username

if [[ $NEON == "false" ]]; then
    pkcon_update
else
    apt_update
fi

apt_install
install_antibody
change_shell
install_lsd
install_go
setup_wsl
install_con_fonts
setup_shims
install_docker

if [[ $COMMANDLINE_ONLY == "false" && $WSL == "false" ]]; then
    snap_install
    setup_flatpak
    install_chrome
    #install_1password
    install_inkscape
    install_discord
    install_kvantum
    install_layan
    fix_sddm
fi

setup_openrazer
if [[ $STREAMING == "true" ]]; then
    setup_obs
fi
fix-update-grub

if [[ $COMMANDLINE_ONLY == "false" ]]; then
    install_nerd_fonts
fi

# Post install tasks:
show_msg "Linking /usr/bin/python3 to /usr/bin/python..."
sudo ln -s /usr/bin/python3 /usr/bin/python

cd $STARTPWD

show_msg "Ubuntu Setup Script has finished installing..."
exit 0
