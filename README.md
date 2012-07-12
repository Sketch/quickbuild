# NAME

*Quickbuild* - offline MUSH building tool

# SYNOPSIS

*quickbuild* [options] area.txt

# DESCRIPTION

*Quickbuild* is a Ruby script that lets you quickly lay out a MUSH area
(a set of rooms connected by exits, optionally zoned and/or parented)
in an easy-to-use format in a text file.  It's smart about cardinal
directions (aliases and reverse exits), &lt;b&gt;racket style exit-naming,
and a few other things. It can build over and modify areas already built
by a *Quickbuild* script, enabling easy offline management of a whole MUSH
grid.

*Quickbuild* is a very simple Ruby script: It has no dependencies, and can be
run on any modern Ruby without installing gems or libraries.  It accepts a
list of filenames as arguments, and produces uploadable MUSH code on stdout.

* * *
## Quickbuild File Format

An input file for *Quickbuild* can include the following:

### Comments

Lines beginning with # are considered comments and ignored.
In an IN or ON section (see below), only lines beginning with @@ are ignored.

### Building commands

A line of the form:

    "Exit name" : "Source Room Name" -> "Destination Room Name" [-> "Next dest"]

will be translated into instructions to create the source and
destination rooms and open an exit from the source to the destination.
If multiple destination rooms are provided, additional exits will
be opened from each one to the one that follows, creating a line of rooms.

The default configuration file defines a few special exit names:
 n, s, e, w, ne, nw, se, sw, u, d, and out. If you use one of these names,
it will automatically be expanded into a complete set of exit aliases. For
example, "n" will be expanded to "&lt;N&gt;orth;nort;nor;no;n". "out"
is expanded to "&lt;O&gt;ut;back;leave;exit;out;o".

Exits with defined reverse exits (such as those in the default config file)
can also be used to automatically open exits between rooms in both directions,
like this:

    "n" : "Source Room Name" <-> "Destination Room Name" [<-> "Next dest"]

This will open a north exit from source to destination and a south exit
back from destination to source.

### Name tags

You can "tag" room names by putting a single word after the ending quote:

    "Exit name" : "Room Name"tag1 <-> "Room Name"tag2

Both rooms will be built with the name "Room Name", but stored on the builder
character as different attributes. Name tags are useful when you're building
things like mazes, or just want to confuse the Players for some reason. :)
Anywhere you can use a room name, you can also use a name tag.

### Dbref storage

When rooms are built, their dbrefs are stored on the building player
using attributes with names like `ROOM.<room_name>`. When storing
room names in attributes, spaces names are converted to underscores,
and special characters are converted to $ followed by the ASCII hex
code for that character.

You can change the "ROOM." prefix with the line

    ATTR BASE: <new prefix>

*Quickbuild* recognizes attribute tree prefixes (e.g. "QB\`ROOM\`") and
creates placeholder attributes for the branches.

### Zones and Parents

You can set a default zone to be assigned to rooms with the line

    ROOM ZONE: <dbref of ZMO> or "Room Name"

*Quickbuild* will generate @chzone commands setting the zone of any rooms
defined after the ROOM ZONE: command. Note that a room is defined when it
is first used in the input. You may use additional ROOM ZONE: commands
to change the active room zone.

If you provide a room name instead of a dbref, the room will be
created by the script *Quickbuild* generates.

You can set default exit zones, room parents, and exit parents
with EXIT ZONE:, ROOM PARENT:, and EXIT PARENT: commands. Note that
if you're not providing dbrefs, you should be providing a room
name, even if you're setting exit zone/parent. That is, *Quickbuild*
will generate a room as the exit parent (which doesn't hurt).

Note that you cannot parent a room parent with *Quickbuild*. It's trivial
to do so manually, however.

### Flags

You can set default flags to be @set on rooms with the line

    ROOM FLAGS: <flag> <flag> <flag> ...

Simiarly, EXIT FLAGS: sets default exit flags.

### Defining aliases

The syntax for defining an exit alias is:

    alias "<alias>" "<full exit name>"

For example:

    alias "n" "<N>orth;north;nort;nor;no;n"`

### Defining Reverse Exits

The syntax for defining reverse exits is:

    reverse "<alias or name>" "<alias or name>"

For example:

    reverse "n" "s"

If you're defining reverse exits for aliased exits, always use the
alias, rather than the full exit name. The reverse command makes BOTH
of its arguments the reverse of the other, unless the --noreverse
option is specified.

### Custom Code

The DESCRIBE command can be used to add descriptions to rooms:

    DESCRIBE "Room name" =The room description goes here, without quotes.

If you need to do more than just @describe a room,
you can add custom code that will be executed in a given room like this:

    IN "Room Name"
    ...MUSH code in mpp format here...
    ENDIN

You can add custom code that will be executed in a given room like this:

    ON "Exit Name" FROM "Source Room Name
    ...MUSH code in mpp format here...
    ENDON

mpp format is the format defined by Josh Bell's mpp (MUSH preprocessor)
program. It  works like this:

1. Blank lines and lines starting with @@ are removed.

2. A non-whitespace, non-'&gt;' character in the first
  column indicates the start of a new line of MUSHcode.

3. Leading whitespace on a line is otherwise stripped,
  and indicates the line is a continuation of the previous line

4. (not implemented by *Quickbuild*) Lines starting with '\*'
  (in the first column) are treated
  as continuations and are converted from plain ASCII to
  "MUSH-ready" ASCII, i.e. spaces -&gt; %b, \[ -&gt; \[, etc. %r
  characters are prepended to any subsequent &gt; lines.

5. In any other line, each tab is converted to a space.

* * *
# OPTIONS

### --help

Prints a usage summary

### --nosidefx

By default, *Quickbuild* produces output containing side-effect functions.
Use this option if you want the produced output to only use @commands to
build. The --nosidefx option inherently disables managed mode (see below).
Output produced with the --nosidefx option may not work on some MUSH
codebases. Of particular note, such output will not work on either TinyMUX
or RhostMUSH.

### --unmanaged

By default, *Quickbuild* assumes that it should produce output that will
modify and extend an area that is already built, not build an entirely new
area.
The code produced will not dig a new room if a `<attr_base><room_name>`
attribute exists on the Player executing the code, nor will it open an exit
if an exit of the same name exists in the relevant room. It WILL re-link
an existing exit of a given name to a changed destination.
The code produced WILL change the parents, zones, and flags, do @describes,
and execute the IN and ON clauses for all rooms and exits.
Most importantly, the code produced will NOT remove exits and rooms no longer
mentioned in the input file. That job falls upon the MUSH's warning system
and the builder player.
NOTE: Managed mode cannot be used with the --nosidefx option. Managed mode
will also not work on MUSH codebases without these functions:
dig() or a create() that can make rooms, link(), open() or a create() that
can make exits, parent() that alters parents, setr() and r(), and a switch()
that does wildcard matching.
(All codebases are assumed to have ifelse(), t(), and v().)

### --nobrackets

By default, *Quickbuild* assumes that you like the &lt;B&gt;racket style
of exit naming, where the abbreviation in the brackets is the short
name for the exit. Use this option to keep *Quickbuild* from adding aliases
to exits when it detects a bracketed exit name.

### --noreverse

By default, *Quickbuild* assumes that the line REVERSE "a" "b" should
define "b" as the reverse exit of "a", AND "a" as the reverse exit of "b".
Use this option to make REVERSE one-way, and only define
the second argument as the reverse exit of the first argument.

### --config-file <filename>

Use <filename> as the configuration file instead of the default.

### --no-config-file

Don't use any configuration file.

* * *
# CONFIGURATION FILE

By default, *Quickbuild* loads a configuration file that defines a few default
aliases for exits (e.g., "n" for "<N>orth;north;nort;nor;no;n") and reverse
exits (e.g. "n" and "s"). It searches for this file in the following order:

1. Given on the command line with --config-file (stop if found)
2. .qbcfg or qb.cfg in the current directory
3. .qbcfg or qb.cfg in the user's home directory

Configuration files are actually just *Quickbuild* files themselves. You can
use the REVERSE and ALIAS line in your building scripts, or even have a
ROOM PARENT line in your default configuration file.

* * *
# EXAMPLE

Here is an example that illustrates most of the features:

### Input

    ROOM ZONE: "City Zone"
    ROOM FLAGS: transparent
    EXIT PARENT: #444
    "n": "Town Square" <-> "City Gates"
    "e": "Town Square" <-> "Main Street"
    EXIT FLAGS: opaque
    "<M>anhole;manhole;m;down;dow;do;d": "Main Street" -> "Sewer"
    DESCRIBE "City Gates" =You are outside the city gates, which open on Saturdays.
    DESCRIBE "Town Square" =This is town square.
    ON "s" FROM "City Gates"
    &dayofweek s=first(time())
    @lock s = dayofweek/Sat
    ENDON

### Resulting Output (with --unmanaged)

    think Creating room & exit zones as things
    @dig/teleport City Zone
    think set(me,ROOM.City_Zone:[create(City Zone,10)])
    @lock [v(ROOM.City_Zone)]= =me
    @lock/zone [v(ROOM.City_Zone)]= =me
    @link [v(ROOM.City_Zone)]=me
    think Digging Rooms
    @dig/teleport Town Square
    think set(me,ROOM.Town_Square:%l)
    @chzone here=[v(ROOM.City_Zone)]
    @set here=transparent
    @describe here=This is town square.
    @dig/teleport City Gates
    think set(me,ROOM.City_Gates:%l)
    @chzone here=[v(ROOM.City_Zone)]
    @set here=transparent
    @describe here=You are outside the city gates, which open on Saturdays.
    @dig/teleport Main Street
    think set(me,ROOM.Main_Street:%l)
    @chzone here=[v(ROOM.City_Zone)]
    @set here=transparent
    @dig/teleport Sewer
    think set(me,ROOM.Sewer:%l)
    @chzone here=[v(ROOM.City_Zone)]
    @set here=transparent
    think Linking Rooms
    @teleport [v(ROOM.Town_Square)]
    @open North <N>;north;nort;nor;no;n=[v(ROOM.City_Gates)]
    @parent North <N>=#444
    @open East <E>;east;eas;ea;e=[v(ROOM.Main_Street)]
    @parent East <E>=#444
    @teleport [v(ROOM.City_Gates)]
    @open South <S>;south;sout;sou;so;s=[v(ROOM.Town_Square)]
    @parent South <S>=#444
    &dayofweek s=first(time())
    @lock s = dayofweek/Sat
    @teleport [v(ROOM.Main_Street)]
    @open West <W>;west;wes;we;w=[v(ROOM.Town_Square)]
    @parent West <W>=#444
    @open <M>anhole;M;manhole;m;down;dow;do;d=[v(ROOM.Sewer)]
    @parent <M>anhole=#444
    @set <M>anhole=opaque
    think WARNING: Creating room with no exits: Sewer
    @teleport [v(ROOM.Sewer)]


In this silly example, an input of 426 characters resulted in an output of
1631 characters, so you saved considerable typing time.

* * *
# RESTRICTIONS

Exits originating from the same source room must have unique names.

* * *
# COMPATIBILITY
Considerable effort has been taken to make the code generated by *Quickbuild*
compatible with PennMUSH, TinyMUX, and RhostMUSH. However, there are some
incorrigible codebase discrepancies.

- Building on TinyMUX and RhostMUSH cannot be done if --nosidefx is enabled.
- RhostMUSH requires the SIDEFX flag be set on the builder character.
- RhostMUSH zones use @zone, not @chzone, as objects can have multiple zones.
  To emulate single-zoning on RhostMUSH, make an alias in your client for
  `@chzone *=*` --> `@zone/purge %0` &lt;newline&gt; `@zone/add %0=%1`

If you would like to see compatibilty added for another kind of MU-like,
please contact me. If a codebase gets enough attention, I'll try to code
for it. If you want to fork the code and add codebase support yourself,
I recommend making process\_graph more sophisticated than the tree of
if-elses it currently is.

* * *
# AUTHOR

*Quickbuild* was originally coded by Alan Schwartz. The original Perl
version is available here:
    http://download.pennmush.org/Accessories/

The modern Ruby version is authored by Ryan Dowell, and distributed under the
same license as PennMUSH. The latest version of *Quickbuild* is available here:
    https://github.com/Sketch/quickbuild
