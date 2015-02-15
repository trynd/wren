#!/bin/sh
#
# NAME
#
#   update-grub.sh
#
# DESCRIPTION
#
#   Writes a new grub.cfg file to match current device save data.
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

# constants / functions
NAME=`basename "$0"`
USAGE="
NAME

    $NAME

DESCRIPTION

    Writes a new grub.cfg file to match current device save data to standard
    output. Use redirection to write to a file.
"
printUsage()
{
    echo "$USAGE"
    test x"$1" = x || exit $1
}

fail()
{
    test x"$1" = x \
        && echo "An error occured - exiting..." >&2 \
        || echo "$1 - exiting..." >&2

    exit 1
}

# load platform environment
test x"$RUN_ENV_PLATFORM_PATH" != x \
    && . "$RUN_ENV_PLATFORM_PATH/platform-env" \
    && loadRunEnvConf \
    && updateBootOptions \
    || fail "Unable to load platform environment"

# ensure platform name
testVariableDefinition RUN_ENV_PLATFORM_NAME \
    || fail "Unable to determine platform name"

# ensure platform display name
testVariableDefinition RUN_ENV_PLATFORM_DISPLAY_NAME \
    || fail "Unable to determine platform display name"

# ensure boot device is mounted
testVariableDefinition MOUNT_DEVICE \
    && testIsMounted "$MOUNT_DEVICE" \
    || fail "Boot device does not appear to be mounted"

# ensure other required variables are defined
testVariableDefinition BOOT_DEVICE \
    || BOOT_DEVICE="LABEL=$RUN_ENV_PLATFORM_NAME"
testVariableDefinition DEVICE_DIRECTORY_IMAGES \
    || DEVICE_DIRECTORY_IMAGES=/boot/images
testVariableDefinition DEVICE_DIRECTORY_SAVES \
    || DEVICE_DIRECTORY_SAVES=/boot/save
testVariableDefinition PLATFORM_IMAGE_KERNEL \
    || PLATFORM_IMAGE_KERNEL=vmlinuz
testVariableDefinition PLATFORM_IMAGE_INITRD \
    || PLATFORM_IMAGE_KERNEL=initrd.img

###
### END CONFIG
###


### GENERATOR

generate()
{
    # required
    local heading
    local directory
    # optional
    local options
    local fallback_directory
    # local
    local mount_device
    local kernel
    local initrd
    local fallback_kernel
    local fallback_initrd
    local versioned_kernel
    local kernel_version

    heading="$1"
    directory="$2"
    options="$3"
    fallback_directory="$4"

    test x"$heading" = x && return 1

    mount_device=${MOUNT_DEVICE%/}

    if test x"$directory" != x; then
        directory="${directory%/}"
        directory="/${directory#/}"
    fi

    # if the preferred directory doesn't exist, try only using the fallback
    if test x"$directory" = x -o ! -d "$mount_device$directory"; then
        test x"$fallback_directory" != x \
            && generate "$heading" "$fallback_directory" "$options"
        return $?
    fi

    kernel="$directory/$PLATFORM_IMAGE_KERNEL"
    initrd="$directory/$PLATFORM_IMAGE_INITRD"

    if test x"$fallback_directory" != x; then
        fallback_directory="${fallback_directory%/}"
        fallback_directory="/${fallback_directory#/}"
        fallback_kernel="$fallback_directory/$PLATFORM_IMAGE_KERNEL"
        fallback_initrd="$fallback_directory/$PLATFORM_IMAGE_INITRD"
    fi

    # if they don't both exist without version numbers in the preferred
    # directory, search for version numbered files in the preferred and fallback
    # directories.
    if test ! -f "$mount_device$kernel" -o ! -f "$mount_device$initrd"; then

        # find a workable kernel
        versioned_kernel=`getNewestExistingVersionedFilePath "$mount_device$kernel"` \
            && kernel_version="${versioned_kernel#$mount_device$kernel}" \
            && test x"$kernel_version" != x \
            && kernel="$kernel$kernel_version" \
            ||  {
                    test x"$fallback_directory" != x -a -d "$mount_device$fallback_directory" \
                        && kernel="$fallback_kernel" \
                        && versioned_kernel=`getNewestExistingVersionedFilePath "$mount_device$kernel"` \
                        && kernel_version="${versioned_kernel#$mount_device$kernel}" \
                        && test x"$kernel_version" != x \
                        && kernel="$kernel$kernel_version" \
                        || return $?
                }

        # find a matching initrd
        # first check the preferred directory for a versioned initrd image
        initrd="${directory}/$PLATFORM_IMAGE_INITRD$kernel_version"
        if ! test -f "$mount_device$initrd"; then

            # check the fallback directory
            if test x"$fallback_directory" != x -a -d "$mount_device$fallback_directory"; then

                # first check the fallback directory for unversioned images
                if test -f "$mount_device$fallback_kernel" -a -f "$mount_device$fallback_initrd"; then
                    kernel="$fallback_kernel"
                    initrd="$fallback_initrd"
                else
                    # check the fallback directory for a versioned initrd image
                    initrd="$fallback_initrd$kernel_version" \
                    && test -f "$mount_device$initrd" \
                    || return $?
                fi

            else

                return 1

            fi

        fi
    fi

    test x"$options" = x || options=" $options"

    echo "

menuentry \"$heading\" {
    linux $kernel root=$BOOT_DEVICE$options
    initrd $initrd
}"

    return 0
}


### HEADER

# begin the save contents
result="# AUTO-GENERATED
set timeout=10
set default=0"


### SAVE IMAGES

# get saves path
path_dir_saves=`getDeviceSavesDirectoryPath` \
    && test x"$path_dir_saves" != x \
    || fail "Unable to determine device save storage directory"

if test -d "$path_dir_saves"; then
    # iterate over saves, adding to output along the way
    saves=`getAbsoluteDirectoryList "$path_dir_saves"` \
        || fail "Unable to load save storage directory content"
    while IFS= read -r i; do
        if test -d "$i"; then
            save=`basename "$i"` || fail

            menuentry=`generate "$RUN_ENV_PLATFORM_DISPLAY_NAME (Load Save: $save)" "${DEVICE_DIRECTORY_SAVES%/}/$save" "$RUN_ENV_PLATFORM_NAME-save=$save" "$DEVICE_DIRECTORY_IMAGES"` \
                && result="$result$menuentry"
        fi
    done <<EOF
$saves
EOF
fi


### CORE IMAGES

### NEW (No Save Image)

menuentry=`generate "$RUN_ENV_PLATFORM_DISPLAY_NAME (New)" "$DEVICE_DIRECTORY_IMAGES" "$RUN_ENV_PLATFORM_NAME-skip-save"` \
    && result="$result$menuentry"

### NEW WITH SWAP

menuentry=`generate "$RUN_ENV_PLATFORM_DISPLAY_NAME (New With Swap)" "$DEVICE_DIRECTORY_IMAGES" "$RUN_ENV_PLATFORM_NAME-skip-save $RUN_ENV_PLATFORM_NAME-swap=LABEL=SWAP"` \
    && result="$result$menuentry"

### NEW TO RAM

menuentry=`generate "$RUN_ENV_PLATFORM_DISPLAY_NAME (New To RAM)" "$DEVICE_DIRECTORY_IMAGES" "$RUN_ENV_PLATFORM_NAME-skip-save $RUN_ENV_PLATFORM_NAME-to-ram"` \
    && result="$result$menuentry"

### NEW TO RAM WITH UNMOUNT

menuentry=`generate "$RUN_ENV_PLATFORM_DISPLAY_NAME (New To RAM - Remove Media)" "$DEVICE_DIRECTORY_IMAGES" "$RUN_ENV_PLATFORM_NAME-skip-save $RUN_ENV_PLATFORM_NAME-unmount"` \
    && result="$result$menuentry"

### NEW WITH TEST MODE

menuentry=`generate "$RUN_ENV_PLATFORM_DISPLAY_NAME (New - TEST MODE - Log All - No Boot)" "$DEVICE_DIRECTORY_IMAGES" "$RUN_ENV_PLATFORM_NAME-skip-save $RUN_ENV_PLATFORM_NAME-test-mode"` \
    && result="$result$menuentry"

echo "$result"
