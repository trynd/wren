#!/bin/sh
#
# NAME
#
#   save.sh
#
# DESCRIPTION
#
#   Saves current working save content to a standard save image.
#
# AUTHOR
#
#   Originally written by Michael Spencer.
#   Maintained by the Wren project developers.
#
#
# The Wren project; Copyright 2013-2015 the Wren project developers.
# See the COPYRIGHT file in the top-level directory of this distribution
# for individual attributions.
#
# This file is part of the Wren project. It is subject to the license terms
# in the LICENSE file found in the top-level directory of this distribution.
# No part of the Wren project, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# This program comes with ABSOLUTELY NO WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# LICENSE file found in the top-level directory of this distribution for
# more details.
#


###
### CONFIG
###


# clean environment
unset IFS
PATH=/usr/sbin:/usr/bin:/sbin:/bin


# usage
printUsage()
{
    local name

    name=`basename "$0"`
    cat <<EOF

NAME

    $name

DESCRIPTION

    Root (or sudo) permissions are required to run this script.

    Saves current working save content to a standard save image.

SYNOPSIS

    $name [OPTIONS] [OUTPUT_FILE]

EXAMPLES

    NO OPTIONS          Save the working content to a save file in the current
                        user save directory.

        $name

    ALTERNATE SAVE      Build a new save file or update an existing save file in
                        the specified user save directory for a user save named
                        "test".

        $name -s "test"

    BACKUP SAVE         Create or update a save file in a non-standard location.

        $name -f /tmp/save.2fs

OPTIONS

        -f, --file      File path to use as storage. This option is not normally
                        required, and only exists to be explicit about the
                        following parameter being the OUTPUT_FILE path in case
                        the file name begins with a hyphen (-).

        -h, --help      Print this usage information.

        --no-snapshot   Skip creating a snapshot even if may be possible. Copy
                        directly from the active file system.

        -s, --save      When no OUTPUT_FILE is provided, this option is used to
                        set the save name used to determine the path to the save
                        file on the boot media.

        OUTPUT_FILE     Path to the output storage file. If this is not
                        provided, the current default save file path will be
                        used instead.

EOF

    test x"$1" != x && exit $1
}


# ensure platform name is defined
test x"${RUN_ENV_PLATFORM_PATH}" = x \
    && { echo "Could not determine platform environment path - exiting..." >&2 ; exit 1 ; }


# load platform environment
. "${RUN_ENV_PLATFORM_PATH}/lib/platform-env" \
    || { echo "Could not load platform environment - exiting..." >&2 ; exit 1 ; }


# local functions
panicExit()
{
    test x"$1" = x \
        && echo "An error occurred - exiting..." >&2 \
        || echo "${1} - exiting..." >&2

    test x"$pid_name" = x \
        || deletePidFile "$pid_name"

    exit 1
}


# ensure root permissions
testRootUser || panicExit "Root permissions (or sudo) required"


# load boot configurations and options
loadRunEnvConf || panicExit
updateBootOptions || panicExit


# parse options
file=""
save_name=""
flag_file=0
flag_save=0
no_snapshot=0
for i in "$@"; do
    if test x"$flag_file" = x1; then
        file=$i
        flag_file=0
    elif test x"$flag_save" = x1; then
        save_name=$i
        flag_save=0
    else
        case $i in

            -f|--file )     flag_file=1 ;;

            -f* )           file=${i#-f} ;;

            -h|--help )     printUsage 0 ;;

            --no-snapshot ) no_snapshot=1 ;;

            -s|--save )     flag_save=1 ;;

            -s* )           save_name=${i#-s} ;;

            -* )            panicExit "Unknown option \"$i\"" ;;

            * )             file=$i ;;

        esac
    fi
done


# ensure save file path is provided
if test x"$file" = x; then
    file=`getSaveImagePath "$save_name"` || printUsage 1
fi
test x"$file" = x && printUsage 1
test -d "$file" \
    && panicExit "Given save file path already exists as a directory"
testImageLooped "$file" \
    && panicExit "Device loop found for save file - may already be mounted"
# define full path to file
file=`readlink -m "$file"` || panicExit
filename=`basename "$file"` || panicExit
filedir=`dirname "$file"` || panicExit


# check for required variables
testVariableDefinition PLATFORM_FILESYSTEM_READWRITE        || panicExit
testVariableDefinition MOUNT_SAVE                           || panicExit
testVariableDefinition MOUNT_TMP                            || panicExit
testVariableDefinition MOUNT_SAVE_TMP                       || panicExit
testVariableDefinition MOUNT_SNAPSHOT_TMP                   || panicExit
testVariableDefinition PLATFORM_IMAGE_SAVE_SIZE             || panicExit
testVariableDefinition PLATFORM_IMAGE_SAVE_SIZE_INCREMENT   || panicExit
testVariableDefinition PLATFORM_IMAGE_SAVE_RESIZE_TOLERANCE || panicExit
testVariableDefinition RUN_ENV_DIRECTORY                    || panicExit
testVariableDefinition RUN_ENV_DIRECTORY_TMP                || panicExit


###
### END CONFIG
###


# create pid file (or exit if already running)
pid_name=save
createPidFile "$pid_name" "$$" || { pid_name= ; panicExit ; }


# whether to create a snapshot
use_snapshot=0


# if snapshots are not specifically disabled
if test x"$no_snapshot" = x0; then


    # determine whether to use a snapshot
    active_volume_image_path=`getActiveVolumeImagePath` \
        && test -f "$active_volume_image_path" \
        && active_volume_root_subvolume_path=`getActiveVolumeRootSubvolumePath` \
        && test -d "$active_volume_root_subvolume_path" \
        && active_volume_root_snapshot_subvolume_path=`getActiveVolumeRootSnapshotSubvolumePath` \
        && test x"$active_volume_root_snapshot_subvolume_path" != x \
        && use_snapshot=1 \
        || echo "Snapshot not possible - falling back to standard copy mode"


else


    echo "Proceeding without snapshot..."


fi



# create snapshot (if possible)
if test x"$use_snapshot" = x1; then


    echo "Creating snapshot..."


    # create a snapshot of the active volume's root subvolume
      createSubvolumeSnapshot \
          "$active_volume_root_subvolume_path" \
          "$active_volume_root_snapshot_subvolume_path" \
          || panicExit


    # Ensure volume information is up to date
    sync


    # mount the snapshot subvolume to the standard tmp snapshot location
    mkdir -p "$MOUNT_SNAPSHOT_TMP" || panicExit
    mount --bind -o ro \
        "$active_volume_root_snapshot_subvolume_path" \
        "$MOUNT_SNAPSHOT_TMP" \
        || panicExit
    # readonly must be set separately for bind mounts in some kernels
    mount -o remount,ro "$MOUNT_SNAPSHOT_TMP" || panicExit


fi


# bind the save data source to a central (readonly) tmp mount
mkdir -p "$MOUNT_TMP" || panicExit
test x"$use_snapshot" = x1 \
    && { mount --bind -o ro "$MOUNT_SNAPSHOT_TMP" "$MOUNT_TMP" || panicExit ; } \
    || { mount --bind -o ro "$MOUNT_SAVE" "$MOUNT_TMP" || panicExit ; }
# readonly must be set separately for bind mounts in some kernels
mount -o remount,ro "$MOUNT_TMP" || panicExit


# determine save data size
echo "Determining save data size..."
save_data_size=`getDiskUsage "$MOUNT_TMP"` || panicExit


# add our data tolerance to the save data size so we don't have to manually
# include it in later calculations
save_data_size=$(($save_data_size+$PLATFORM_IMAGE_SAVE_RESIZE_TOLERANCE)) \
    || panicExit "$save_data_size"


# create save file (if does not exist)
loop_save=""
if test ! -f "$file"; then


    echo "Creating new save file..."


    # calculate required save file size
    save_file_size=$PLATFORM_IMAGE_SAVE_SIZE
    while test "$save_file_size" -le "$save_data_size"; do
        save_file_size=$(($save_file_size+$PLATFORM_IMAGE_SAVE_SIZE_INCREMENT)) \
            || panicExit
    done


    # ensure availability of working directories
    mkdir -p "$filedir" || panicExit
    mkdir -p "$RUN_ENV_DIRECTORY_TMP" || panicExit


    # create file in /tmp
    file_tmp=$RUN_ENV_DIRECTORY_TMP/save-$filename.tmp
    dd if=/dev/null of="$file_tmp" \
        bs=1 seek="$save_file_size" count=0 1>/dev/null \
        || panicExit


    # move file to final destination
    mv "$file_tmp" "$file" || panicExit


    # acquire save loop
    loop_save=`losetup -f` || panicExit
    loopImage "$file" "$loop_save" || panicExit


    # format new save file
    mke2fs -t $PLATFORM_FILESYSTEM_READWRITE "$loop_save" 1>/dev/null || panicExit


    # free save loop
    unloopLoop "$loop_save" || panicExit
    loop_save=""


# resize save file (if smaller than save data)
else


    # get save file size
    save_file_size=`getFileSize "$file"` || panicExit


    # resize save file (if not big enough to hold data)
    if test "$save_file_size" -lt "$save_data_size"; then


        echo "Expanding save file..."


        # calculate new file size
        new_save_file_size=$save_file_size
        while test "$new_save_file_size" -lt "$save_data_size"; do
            new_save_file_size=$(($new_save_file_size+$PLATFORM_IMAGE_SAVE_SIZE_INCREMENT)) \
                || panicExit
        done
        size_difference=$(($new_save_file_size-$save_file_size)) \
            || panicExit "$size_difference"


        # ensure image isn't already looped
        testImageLooped "$file" && panicExit "Device loop found for save file - may already be mounted"


        # acquire save loop
        loop_save=`losetup -f` || panicExit
        loopImage "$file" "$loop_save" || panicExit


        # check existing filesystem
        e2fsck -f "$loop_save"
        test "$?" -gt 2 && panicExit


        # expand filesystem
        truncate -c -s +"$size_difference" "$file" || panicExit
        resize2fs "$loop_save" || panicExit


        # check new filesystem
        e2fsck -f "$loop_save"
        test "$?" -gt 2 && panicExit


        # free save loop
        unloopLoop "$loop_save" || panicExit
        loop_save=""


    fi


fi


# mount save file
loop_save=`losetup -f` || panicExit
mkdir -p "$MOUNT_SAVE_TMP" || panicExit
mountImage $PLATFORM_FILESYSTEM_READWRITE rw "$file" "$MOUNT_SAVE_TMP" "$loop_save" || panicExit


# copy contents
echo "Copying save data..."
rsync -axHAXSv --delete-excluded --delete-before \
    --exclude "$file" \
    --exclude /tmp \
    --exclude "$RUN_ENV_DIRECTORY" \
    --exclude "$RUN_ENV_DIRECTORY_TMP" \
    "$MOUNT_TMP/" "$MOUNT_SAVE_TMP" \
    || panicExit


echo "Cleaning up..."


# remove central tmp mount
umount "$MOUNT_TMP" || panicExit
rmdir "$MOUNT_TMP"


# clean up the snapshot
if test x"$use_snapshot" = x1; then


    # unmount standard snapshot tmp location bind mount
    umount "$MOUNT_SNAPSHOT_TMP" || panicExit
    rmdir "$MOUNT_SNAPSHOT_TMP"


    # delete the snapshot subvolume
    deleteSubvolume "$active_volume_root_snapshot_subvolume_path" || panicExit


fi


# unmount save file
umount "$MOUNT_SAVE_TMP" || panicExit
rmdir "$MOUNT_SAVE_TMP"


# free save loop
test x"$loop_save" = x \
    || { unloopLoop "$loop_save" && loop_save= || panicExit ; }


# delete pid file
deletePidFile "$pid_name"


echo "Save complete."
