# 200_inject_default_boothd0_boot_method.sh
# Only to be used in the following circumstances:
# 1. recover work-flow
# 2. OUTPUT=PXE and PXE_CONFIG_URL style
# 3. mount path from PXE_CONFIG_URL
# 4. append "default boothd0" line in rear-$client PXE configuration so that after the restore it boots from the 1st HD instead
#    of the network 
# 5. umount path again

# step 1 - if not in recover workflow just return
[[ "$WORKFLOW" != "recover" ]] && return

# step 2 - only continue if OUTPUT=PXE
# DO not check Output as script is saved in the proper path and this way we can use it for PXE and ISO boot methods
# [[ "$OUTPUT" != "PXE" ]] && return
# Also, only valid when we used the PXE_CONFIG_URL style
[[ -z "$PXE_CONFIG_URL" ]] && return

# step 3 - mount PXE_CONFIG_URL path
local scheme=$( url_scheme $PXE_CONFIG_URL )
local path=$( url_path $PXE_CONFIG_URL )
mkdir -p $v "$BUILD_DIR/tftpbootfs" >&2
StopIfError "Could not mkdir '$BUILD_DIR/tftpbootfs'"
AddExitTask "rm -Rf $v $BUILD_DIR/tftpbootfs >&2"
mount_url $PXE_CONFIG_URL $BUILD_DIR/tftpbootfs
PXE_LOCAL_PATH=$BUILD_DIR/tftpbootfs

# step 4 - append "default boothd0" to the PXE config file of host "client"
# PXE_CONFIG_PREFIX is a "string" (by default rear-) - is the name of PXE boot configuration of $HOSTNAME
PXE_CONFIG_FILE="${PXE_CONFIG_PREFIX}$HOSTNAME"
echo "default boothd0" >> "$PXE_LOCAL_PATH/$PXE_CONFIG_FILE"
chmod 444 "$PXE_LOCAL_PATH/$PXE_CONFIG_FILE"

# step 5 - umount path
LogPrint "Updated pxelinux config '${PXE_CONFIG_PREFIX}$HOSTNAME' to boot from first hard disk at next reboot"
umount_url $PXE_CONFIG_URL $BUILD_DIR/tftpbootfs
rmdir $BUILD_DIR/tftpbootfs >&2
if [[ $? -eq 0 ]] ; then
    RemoveExitTask "rm -Rf $v $BUILD_DIR/tftpbootfs >&2"
fi


