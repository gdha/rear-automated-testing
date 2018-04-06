pushd $ROOTFS_DIR >/dev/null
    if [[ -f etc/udev/rules.d/70-persistent-net.rules ]];  then
        rm -f etc/udev/rules.d/70-persistent-net.rules
        Log "Removed the 70-persistent-net.rules udev rules file to avoid LAN interface renaming"
    fi
popd >/dev/null

