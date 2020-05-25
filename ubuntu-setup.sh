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
    else
        USERNAME=$SUDO_USER
    fi
    if [ $USERNAME == "root" ]; then
        USER_PATH="/root"
    else
        USER_PATH="/home/$USER"
    fi
}

usage() {
    echo -e "Usage:"
    echo -e "  -V  --verbose            Shows command output for debugging"
    echo -e "  -v  --version            Shows version details"
    echo -e "  -h  --help               Shows this usage message"
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

apt_install() {
    show_msg "Installing from apt... "

    apt_pkgs=("git" "curl" "zsh"  "python3.8-dev" "python3-pip"
    "build-essential" "jed" "htop" "links" "lynx" "tree" "tmux" "openjdk-11-jdk" "openjdk-8-jdk"
    "maven" "vim" "vim-nox"  "vim-scripts" "most" "ruby-dev" "scdaemon"
    "pinentry-tty" "pinentry-curses" "libxml2-utils")

    x_apt_pkgs=("idle-python3.8" "vim-gtk3" "pinentry-qt" "libappindicator3-1")

    PKGS=(${apt_pkgs[@]})
    if [[ $COMMANDLINE_ONLY == "false" ]]; then
        for pkg in ${x_apt_pkgs[@]}; do
            PKGS="${PKGS}${pkg} "
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
    exit 0
    sudo apt-get install $PKGS
}

snap_install() {
    show_msg "Installing the following packages from snap:"
    show_msg "Insomnia"
    show_msg "Slack"
    show_msg "Spotify"
    show_msg "Visual Studio Code"
    show_msg "yq"

    if [ $VERBOSE == "true" ]; then
        exec > /dev/tty
    fi

    which slack > /dev/null
    if [ $? != 0 ]; then
        sudo snap install slack --classic
    fi
    which spotify > /dev/null
    if [ $? != 0 ]; then
        sudo snap install spotify --classic
    fi
    which code > /dev/null
    if [ $? != 0 ]; then
        sudo snap install code --classic
    fi
    which insomnia > /dev/null
    if [ $? != 0 ]; then
        sudo snap install insomnia
    fi
    which yq > /dev/null
    if [ $? != 0 ]; then
        sudo snap install yq
    fi

    if [ $VERBOSE == "false" ]; then
        exec > /dev/null 
    fi
}

install_chrome() {
    which google-chrome
    if [ $? != 0 ]; then
        show_msg "Installing Google Chrome (Latest)..."
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        if [ ! -f "google-chrome-stable_current_amd64.deb" ]; then
            show_msg "${red}Failed to download Google Chrome... ${normal}${green}Skipping install...${normal}"
            return
        fi
        sudo dpkg -i google-chrome-stable_current_amd64.deb 
        rm google-chrome-stable_current_amd64.deb 
    fi
}

install_go() {
    wget -O xidel_0.9.8-1_amd64.deb https://sourceforge.net/projects/videlibri/files/Xidel/Xidel%200.9.8/xidel_0.9.8-1_amd64.deb/download 
    sudo dpkg -i xidel_0.9.8-1_amd64.deb
    GOVER=$(curl -s https://github.com/golang/go/releases.atom | xidel -se '//feed/entry[1]/title' - | cut -d' ' -f2)
    case a in $(uname -m)
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
    sudo tar -zxvf /tmp/${GOVER}.linux-amd64.tar.gz --directory /usr/local/
    rm ${GOVER}.linux-amd64.tar.gz
    if [[ -f "/usr/local/bin/go" ]]; then
        sudo rm /usr/local/bin/go
    fi
    if [[ -f "/usr/local/bin/godoc" ]]; then
        sudo rm /usr/local/bin/godoc
    fi
    if [[ -f "/usr/local/bin/gofmt" ]]; then
        sudo rm /usr/local/bin/gofmt
    fi
    sudo ln -s /usr/local/go/bin/go /usr/local/bin/go
    sudo ln -s /usr/local/go/bin/godoc /usr/local/bin/godoc
    sudo ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt
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

COMMANDLINE_ONLY=false
VERBOSE=false
PRIVATE=false
while [ "$1" != "" ]; do
    case $1 in
        -c | --commandline-only)    COMMANDLINE_ONLY=true
                                    shift
                                    ;;
        -V | --verbose)             VERBOSE=true
                                    shift
                                    ;;
        -v | --version)             version
                                    exit 0
                                    ;;
        -h | --help)                usage
                                    exit 0
                                    ;;
        * )                         echo -e "Unknown option $1...\n"
                                    usage
                                    exit 1
                                    ;;
    esac
    shift
done

set_username

if [ $VERBOSE == "false" ]; then
    echo "Silencing output"
    exec > /dev/null 
fi

apt_update
apt_install

if [[ $COMMANDLINE_ONLY == "false" ]]; then
    snap_install
    install_chrome
    fix_sddm
fi

which antibody
if [ $? != 0 ]; then
    show_msg "Installing antibody..."
    curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
fi

if [[ $(awk -F: '/${USERNAME}/ {print $7}' /etc/passwd) != "/bin/zsh" ]]; then
    show_msg "Changing shells to ZSH... Please enter your passowrd!"
    sudo chsh -s /bin/zsh $USERNAME
fi

show_msg "Installing powerline..."
sudo pip3 install setuptools
sudo pip3 install powerline-status
mkdir -p  ${USER_PATH}/.config/powerline
cp -r /usr/local/lib/python3.8/dist-packages/powerline/config_files/* ${USER_PATH}/.config/powerline/

install_go

show_msg "Linking /usr/bin/python3 to /usr/bin/python..."
sudo ln -s /usr/bin/python3 /usr/bin/python

show_msg "Running jenv/rbenv setup script..."
curl -LSs "$GIT_REPO/linux-env-setup.sh" | bash

show_msg "Running console fonts setup script..."
curl -LSs "$GIT_REPO/console-font-setup.sh" | bash

cd $STARTPWD

show_msg "Update the fonts for your terminal and then restart your shell to fnish"
show_msg "I recommnd actually restarting your whole system at this point"
