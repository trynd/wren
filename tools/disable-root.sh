#!/bin/sh
#
# NAME
#
#   disable-root.sh
#
# DESCRIPTION
#
#   Disables the root account on the system. This may be desirable in an
#   administrator-run system in which sudo grants all root privileges.
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

test x"`id -u`" = x0 \
    || { echo 'Requires root (sudo) permissions... exiting' ; exit 1 ; }

passwd -dl root && echo "root account successfully disabled."
exit $?
