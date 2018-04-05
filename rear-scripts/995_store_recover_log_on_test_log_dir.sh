#
# Copy the logfile and other recovery related files to the vagrant host system,
# at least the part of the logfile that has been written till now.
# We keep this recover log together with the output of the rear-automated-test log
#

# Copy the logfile as rear-$HOSTNAME-${WORKFLOW}.log
# Usually RUNTIME_LOGFILE=/var/log/rear/rear-$HOSTNAME.log
# The RUNTIME_LOGFILE name is set by the main script from LOGFILE in default.conf
# but later user config files are sourced in the main script where LOGFILE can be set different
# so that the user config LOGFILE is used as final logfile name.

# The TEST_LOG_DIR_URL contains the hostname of the vagrant host and the path of $TEST_LOG_DIR
Log "Mounting  $TEST_LOG_DIR_URL"
mkdir -p $v "$BUILD_DIR/logdir" >&2
StopIfError "Could not mkdir '$BUILD_DIR/logdir'"
AddExitTask "rm -Rf $v $BUILD_DIR/logdir >&2"
mount_url $TEST_LOG_DIR_URL $BUILD_DIR/logdir "rw,noatime,nolock"

LogPrint "Save the $LOGFILE to $TEST_LOG_DIR_URL"
cp $v $LOGFILE "$BUILD_DIR/logdir/rear-$HOSTNAME-${WORKFLOW}.log" >&2
chmod 644 "$BUILD_DIR/logdir/rear-$HOSTNAME-${WORKFLOW}.log"

# umount path
Log "Unmounting  $TEST_LOG_DIR_URL"
umount_url $TEST_LOG_DIR_URL $BUILD_DIR/logdir
rmdir $BUILD_DIR/logdir >&2
if [[ $? -eq 0 ]] ; then
    RemoveExitTask "rm -Rf $v $BUILD_DIR/logdir >&2"
fi


