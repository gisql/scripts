#!/usr/bin/env bash

export BASE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
. "$BASE/common.sh"

# Bootstrap:
# ssh <good-ip> tar cf - .ssh .m2/settings.xml | tar xf -
# apt-get install -y git
# git clone git@github.com:gisql/scripts.git

require gsettings

gsettings set org.freedesktop.ibus.panel.emoji unicode-hotkey "[]"
gsettings set org.gnome.desktop.wm.preferences audible-bell false

function clear_fs_with() {
    local mod=$1
    gsettings list-recursively | grep "'<$mod>F[0-9][0-9]*" | while read -r line; do
        new=$(echo "$line" | sed -e "s/.*\[/[/g" -e "s/, '<$mod>F[0-9][0-9]*'//" -e "s/'<$mod>F[0-9][0-9]*',*//")
        group=$(echo "$line" | awk '{ print $1 }')
        key=$(echo "$line" | awk '{ print $2 }')

        gsettings set "$group" "$key" "$new"
    done
}

clear_fs_with "Alt"
clear_fs_with "Super"

# other intellij bindings
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left '[]'
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right '[]'


for i in $(seq 4); do
    gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "['<Super>F$i']"
done

sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get autoremove

sudo apt-get purge ibus*

sudo apt-get install -y vim openssh-server git default-jdk maven postgresql docker docker-compose curl
sudo su - postgres -c 'psql -c "alter user postgres password '"'asdf123'"';"'
sudo su - postgres -c 'psql -c "drop database if exists create_drop;"'
sudo su - postgres -c 'psql -c "create database create_drop;"'

if hash idea 2> /dev/null; then
    echo "Idea already installed"
else
    curl -L curl -L https://download.jetbrains.com/idea/ideaIU-2019.3.4.tar.gz > /tmp/idea.tar.gz
    cd /opt || exit 1
    rm -rf idea*
    sudo tar xfz /tmp/idea.tar.gz
    sudo chown "$(id -g):$(id -u)" idea*
    sudo update-alternatives --install /usr/local/bin/idea idea /opt/idea*/bin/idea.sh 1
fi


########################

sudo snap install spotify
sudo apt-get install -y vlc inkscape octave mypaint kira


################ VPN
sudo apt install network-manager-l2tp network-manager-l2tp-gnome

