#!/bin/sh
#
# NAME
#
#   increase-save-size.sh
#
# DESCRIPTION
#
#   Increases the current active save data storage (RAM-based logical volume)
#   capacity.
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

unset IFS
PATH=/usr/sbin:/usr/bin:/sbin:/bin


# ensure platform name is defined
test x"${RUN_ENV_PLATFORM_PATH}" = x \
    && { echo "Could not determine platform environment path - exiting..." >&2 ; exit 1 ; }


# load platform environment
. "${RUN_ENV_PLATFORM_PATH}/platform-env" \
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

###
### END CONFIG
###


# create pid file (or exit if already running)
pid_name=increase-save-size
createPidFile "$pid_name" "$$" || { pid_name= ; panicExit ; }


# increase save size
increaseLvmSaveSize || panicExit


# delete pid file
deletePidFile "$pid_name"
