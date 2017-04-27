# muttjump

Jump to the original message from a virtual maildir in the [Mutt email client].

Written by Johannes Weißl, released into the public domain.

This script makes mail indexers (like [mairix], [mu], [nmzmail], or [notmuch])
together with Mutt more useful.

These search engines usually create a virtual maildir containing symbolic links
to the original mails, which can be browsed using Mutt.  It would be optimal if
Mutt somehow knew that the two maildir entries identify the same mail, but this
is not that easy (mail folder abstraction from different formats, no tight
integration of mail indexers, etc.).

So if one wants to rename (for setting/clearing flags), delete or edit the
mails, it is only possible using the original mail. This simple script helps to
jump to this message, using e.g. this macro in `~/.muttrc`:

    macro generic ,j "<enter-command>push <pipe-message>muttjump<enter><enter>" "jump to original message"

Don't forget to quit the new Mutt instance (started by muttjump) after the
modifications. To make jumping faster (no keypress required), unset `$wait_key`
in your `~/.muttrc`.

The way described above will open a new instance of Mutt. Another option is to
invoke this script as muttjump-same. In that case, a file `~/.muttjump` will be
created. This file will contain instructions for Mutt, which will, after
sourcing, lead to the jump to the desired message (and deletion of
`~/.muttjump`). For that purpose, following macro might be used:

    macro generic ,j "<enter-command>push <pipe-message>muttjump-same<enter><enter><enter-command>source ~/.muttjump<enter>" "jump to original message"

Note: The latter usage of the script can be activated by creating a symlink
called muttjump-same with this script as a target.


[Mutt email client]: http://www.mutt.org/
[mairix]: https://github.com/rc0/mairix
[mu]: https://github.com/djcb/mu
[nmzmail]: http://www.flpsed.org/hgweb/nmzmail
[notmuch]: https://github.com/notmuch/notmuch
