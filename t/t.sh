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
mkdir -p "$base"/INBOX/Msgid/{new,tmp}

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
mairix_version=mairix
if $MAIRIX --version | grep -E -q '^mairix.* 0\.([0-9]|1[0-9]|2[012])([^0-9]|$)' ; then
    mairix_version=mairix-0.22
fi

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

notmuch_mutt () {
    # notmuch-mutt uses GNU extensions of xargs
    XARGS=$(type -p xargs) PATH=$here/utils:$PATH notmuch-mutt "$@"
}

# -- mu setup --

export MU=mu
export MU_OPTIONS="-q --muhome=$database/mu"
mu_folder=$virtual/mu
$MU index $MU_OPTIONS -m "$base"
# mu < 0.9.2 does not support "--format-links", later versions require it:
mu_find_options="--format=links"
if $MU --version | grep -E -q '^mu.* 0\.([012345678]|9\.[01])([^0-9]|$)' ; then
    mu_find_options=""
fi
mu_version=mu
if $MU --version | grep -E -q '^mu.* 0\.9\.([678]|9\.[012345])([^0-9]|$)' ; then
    mu_version=mu-0.9.9.5
elif $MU --version | grep -E -q '^mu.* 0\.[0123456]([^0-9]|$)' ; then
    mu_version=mu-0.6
fi

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
    find "$1" ! -type d -print0 | sort -z | xargs -0 cat
}

# -- tests --

test1_ok='-f '"$base"'/INBOX -e push "<limit>~i'\''<test1@example\\\.com>'\''<enter><limit>all<enter>"'

$MAIRIX s:test1 2>&1 | egrep -v "^(Matched|Created) "
assertEqual "$mairix_version test1" "$test1_ok" \
    "$(cat_files "$mairix_folder" | "$muttjump" -i $mairix_version)"

notmuch_mutt -o "$notmuch_folder" search subject:test1
assertEqual "notmuch test1" "$test1_ok" \
    "$(cat_files "$notmuch_folder" | "$muttjump" -i notmuch)"

$MU find $MU_OPTIONS $mu_find_options --linksdir="$mu_folder" subject:test1
assertEqual "$mu_version test1" "$test1_ok" \
    "$(cat_files "$mu_folder" | "$muttjump" -i $mu_version)"

echo "+subject:/test1/" | $NMZMAIL -r "$nmzmail_folder" >/dev/null 2>&1
assertEqual "nmzmail test1" "$test1_ok" \
    "$(cat_files "$nmzmail_folder" | "$muttjump" -i nmzmail)"


test_space_ok='-f '"$base"'/INBOX/A Space -e push "<limit>~i'\''<test4@example\\\.com>'\''<enter><limit>all<enter>"'

$MAIRIX s:test4 2>&1 | egrep -v "^(Matched|Created) "
assertEqual "$mairix_version space test" "$test_space_ok" \
    "$(cat_files "$mairix_folder" | "$muttjump" -i $mairix_version)"

notmuch_mutt -o "$notmuch_folder" search subject:test4
assertEqual "notmuch space test" "$test_space_ok" \
    "$(cat_files "$notmuch_folder" | "$muttjump" -i notmuch)"

$MU find $MU_OPTIONS $mu_find_options --linksdir="$mu_folder" --clearlinks subject:test4
assertEqual "$mu_version space test" "$test_space_ok" \
    "$(cat_files "$mu_folder" | "$muttjump" -i $mu_version)"

echo "+subject:/test4/" | $NMZMAIL -r "$nmzmail_folder" >/dev/null 2>&1
assertEqual "nmzmail space test" "$test_space_ok" \
    "$(cat_files "$nmzmail_folder" | "$muttjump" -i nmzmail)"


test_msgid_header_ok='-f '"$base"'/INBOX/Msgid -e push "<limit>~i'\''<test7!#\\\$%&.\\\*\\\+-/=\\\?\\\^_\`\\\{\\\|\\\}~@example\\\.com>'\''<enter><limit>all<enter>"'

$MAIRIX s:test7 2>&1 | egrep -v "^(Matched|Created) "
assertEqual "$mairix_version msgid header test" "$test_msgid_header_ok" \
    "$(cat_files "$mairix_folder" | "$muttjump" -i $mairix_version)"

notmuch_mutt -o "$notmuch_folder" search subject:test7
assertEqual "notmuch msgid header test" "$test_msgid_header_ok" \
    "$(cat_files "$notmuch_folder" | "$muttjump" -i notmuch)"

$MU find $MU_OPTIONS $mu_find_options --linksdir="$mu_folder" --clearlinks subject:test7
assertEqual "$mu_version msgid header test" "$test_msgid_header_ok" \
    "$(cat_files "$mu_folder" | "$muttjump" -i $mu_version)"

echo "+subject:/test7/" | $NMZMAIL -r "$nmzmail_folder" >/dev/null 2>&1
assertEqual "nmzmail msgid header test" "$test_msgid_header_ok" \
    "$(cat_files "$nmzmail_folder" | "$muttjump" -i nmzmail)"
