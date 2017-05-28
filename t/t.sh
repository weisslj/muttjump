#!/bin/bash

log_begin_msg () {
    echo -n "$@"
}
log_end_msg () {
    if [ $1 -eq 0 ]; then
        echo "."
    elif [ $1 -eq 255 ] ; then
        echo " (warning)."
    else
        echo " failed!"
    fi
    return $1
}
. /lib/lsb/init-functions 2>/dev/null || true

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
base=$here/Mail
tmp=$here/tmp
virtual=$tmp/virtual
config=$tmp/config
database=$tmp/database
muttjump=$here/../muttjump
export MUTT=echo
rm -rf "$tmp"
mkdir -p "$virtual" "$config" "$database"
mkdir -p "$base"/INBOX/{new,tmp}
mkdir -p "$base"/INBOX/"A Space"/{new,tmp}

# -- mairix setup --

mairixrc=$config/mairixrc
mairix_folder=$virtual/mairix
mairix_database=$database/mairix
export MAIRIX="mairix -f $mairixrc"
cat >"$mairixrc" <<END
base=$base
maildir=INBOX...
mfolder=$mairix_folder
database=$mairix_database
END
$MAIRIX

# -- notmuch setup --

notmuch_folder=$virtual/notmuch
export NOTMUCH_CONFIG=$config/notmuch-config
export NOTMUCH=notmuch
cat >"$NOTMUCH_CONFIG" <<EOF
[database]
path=$base
EOF
notmuch_database=$base/.notmuch
rm -rf "$notmuch_database"
$NOTMUCH new >/dev/null

# -- mu setup --

export MU=mu
export MU_OPTIONS="-q --muhome=$database/mu"
mu_folder=$virtual/mu
$MU index $MU_OPTIONS -m "$base"

# -- nmzmail setup --

nmzmail_folder=$virtual/nmzmail
nmzmail_database=$database/nmzmail
mkdir -p "$nmzmail_database"
export NMZMAIL="nmzmail -b $nmzmail_database"
$NMZMAIL -i "$base/INBOX" >/dev/null 2>&1

# -- utilities --

assertEqual () {
    log_begin_msg "$1"
    [[ "$2" == "$3" ]]
    retval=$?
    log_end_msg $retval
    if [[ $retval -ne 0 ]] ; then
        echo "1: $2"
        echo "2: $3"
        exit $retval
    fi
}
cat_files () {
    find "$1" ! -type d -exec cat {} \;
}

# -- tests --

test1_ok='-f '"$base"'/INBOX -e push "<limit>~i'\''<test1@example\\\.com>'\''<enter><limit>all<enter>"'

$MAIRIX s:test1 2>&1 | egrep -v "^(Matched|Created) "
assertEqual "mairix test1" "$test1_ok" \
    "$(cat_files "$mairix_folder" | "$muttjump" -i mairix-old)"

notmuch-mutt -o "$notmuch_folder" search subject:test1
assertEqual "notmuch test1" "$test1_ok" \
    "$(cat_files "$notmuch_folder" | "$muttjump" -i notmuch)"

$MU find $MU_OPTIONS --format=links --linksdir="$mu_folder" subject:test1
assertEqual "mu test1" "$test1_ok" \
    "$(cat_files "$mu_folder" | "$muttjump" -i mu)"

echo "+subject:/test1/" | $NMZMAIL -r "$nmzmail_folder" >/dev/null 2>&1
assertEqual "nmzmail test1" "$test1_ok" \
    "$(cat_files "$nmzmail_folder" | "$muttjump" -i nmzmail)"


test_space_ok='-f '"$base"'/INBOX/A Space -e push "<limit>~i'\''<test4@example\\\.com>'\''<enter><limit>all<enter>"'

$MAIRIX s:test4 2>&1 | egrep -v "^(Matched|Created) "
assertEqual "mairix space test" "$test_space_ok" \
    "$(cat_files "$mairix_folder" | "$muttjump" -i mairix-old)"

notmuch-mutt -o "$notmuch_folder" search subject:test4
assertEqual "notmuch space test" "$test_space_ok" \
    "$(cat_files "$notmuch_folder" | "$muttjump" -i notmuch)"

$MU find $MU_OPTIONS --format=links --linksdir="$mu_folder" subject:test4
assertEqual "mu space test" "$test_space_ok" \
    "$(cat_files "$mu_folder" | "$muttjump" -i mu)"

echo "+subject:/test4/" | $NMZMAIL -r "$nmzmail_folder" >/dev/null 2>&1
assertEqual "nmzmail space test" "$test_space_ok" \
    "$(cat_files "$nmzmail_folder" | "$muttjump" -i nmzmail)"
