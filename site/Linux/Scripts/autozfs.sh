function autozfs::ubuntusetup(){
    sudo apt-get install zfsutils-linux
}

function autozfs::rockysetup(){
    sudo dnf install epel-release -y
    sudo dnf install -y https://zfsonlinux.org/epel/zfs-release-2-2.el9.noarch.rpm
    sudo dnf config-manager --enable zfs
    sudo dnf groupinstall "Development Tools" -y
    sudo dnf install kernel-devel -y
    sudo dnf install -y zfs
    sudo dnf install zfs-dkms -y
    sudo modprobe zfs
    echo "zfs" | sudo tee /etc/modules-load.d/zfs.conf
    dkms autoinstall
}

function autozfs::createpool(){
    read -p "Zpool Name: (default data)" zpoolName
    zpoolname=${zpoolname:-data}
    read -p "Raid Level: (default raidz2)" raidlevel
    raidlevel=${raidlevel:-raidz2}
    lsblk | less
    read -p "Devices included in raid: (Exclude /dev) (Ex: sda sdb sdc)" devicelist
    sudo zpool create $zpoolname $raidlevel $devicelist
    read -p "Cache (y/n): (default n)" cacheoption
    cacheoption=${cacheoption:-n}
    if [ $cacheoption == "y" ]; then
        read -p "Drives included in Cache: (Exclude /dev) (Ex: sda sdb sdc)" cachedrives
        zpool add $zpoolname cache $cachedrives
        echo "cache added" 
    else
        echo "no cache"
    fi

    read -p "Mountpoint for zpool" zpoolmount
    sudo zfs set mountpoint=$zpoolmount $zpoolname

    sudo systemctl enable --now zfs-import-cache
    sudo systemctl enable --now zfs.target
    sudo systemctl enable --now zfs-import.target
    sudo systemctl enable --now zfs-mount

}

distro_id=$(. /etc/os-release; echo $ID)
case $distro_id in 
    ubuntu*)
        autozfs::ubuntusetup
    ;;
    rocky*)
        autozfs::rockysetup
    ;;
    *)
        echo "Unsupported OS: $distro_id"
    ;;
    esac

autozfs::createpool