#!/bin/sh
#
# NAME
#
#   rename-user.sh
#
# DESCRIPTION
#
#   Facilitates renaming a user by ensuring their associated group name and
#   home directory path are also updated. Additionally updates references
#   to the home directory in files within the home directory to avoid user
#   login issues.
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

fail()
{
    test x"$1" = x \
        && echo "An error occured - exiting..." >&2 \
        || echo "$1 - exiting..." >&2

    exit 1
}

###
### END CONFIG
###


# require root permissions
test x"`id -u`" = x0 || fail 'Requires root (sudo) permissions'

# load arguments
old_user=$1 && test x"$old_user" != x || fail 'Old username required'
new_user=$2 && test x"$new_user" != x || fail 'New username required'

# verify arguments
test x"$old_user" = x"$new_user" && fail "New username must be different from old username"

# ensure user exists
id -u "$old_user" 2>&1 1>/dev/null || fail "Invalid user: $old_user"

# ensure user is not currently logged in
for i in `users`; do
    test x"$i" = x"$old_user" && fail "User currently logged in: $old_user"
done

# rename the user and associated group (and rename their home directory)
usermod -m -d "/home/$new_user" -l "$new_user" "$old_user" || fail "Failed to rename user"
groupmod -n "$new_user" "$old_user" || fail "Failed to rename group"

# find and replace all references to the user's old home directory in any files
# in their new home directory -- without this there is potential for problems
# during user login
echo "$(
while IFS= read i; do
echo $(readlink -m "$i")
done <<EOF
$(grep "home/$old_user" -Rl "/home/$new_user/"* "/home/$new_user/".* 2>/dev/null)
EOF
)" | sort | uniq | xargs sed -i "s/\<home\/$old_user\>/home\/$new_user/g"
