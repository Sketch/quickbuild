# NAME

*Quickbuild* - MUSH offline building tool

# SYNOPSIS

*quickbuild* [options] area.txt

# DESCRIPTION

*Quickbuild* is a Ruby script that lets you quickly lay out a MUSH area
(a set of rooms connected by exits, optionally zoned and/or parented)
in an easy-to-use format. It converts this file into uploadable MUSH code.
It's smart about cardinal directions (aliases and reverse exits),
&lt;b&gt;racket style, and a few other things.
It accepts a list of filenames as arguments, and
produces uploadable MUSH code on stdout.

* * *
## Quickbuild File Format

An input file for *quickbuild* can include the following:

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

### Dbref storage

When rooms are built, their dbrefs are stored on the building player
using attributes with names like `ROOM.<room_name>`. When storing
room names in attributes, spaces names are converted to underscores,
and special characters are converted to $ followed by the ASCII hex
code for that character.

You can change the "ROOM." prefix with the line

    ATTR BASE: <new prefix>

Quickbuild recognizes attribute tree prefixes (e.g. "QB\`ROOM\`") and
creates placeholder attributes for the branches.

### Zones and Parents

You can set a default zone to be assigned to rooms with the line

    ROOM ZONE: <dbref of ZMO> or "Room Name"

*Quickbuild* will generate @chzone commands setting the zone of any rooms
defined after the ROOM ZONE: command. Note that a room is defined when it
is first used in the input. You may use additional ROOM ZONE: commands
to change the active room zone.

If you provide a room name instead of a dbref, the room will be
created by the script *quickbuild* generates.

You can set default exit zones, room parents, and exit parents
with EXIT ZONE:, ROOM PARENT:, and EXIT PARENT: commands. Note that
if you're not providing dbrefs, you should be providing a room
name, even if you're setting exit zone/parent. That is, *quickbuild*
will generate a room as the exit parent (which doesn't hurt).

Note that you cannot parent a room parent with *quickbuild*. It's trivial
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

### Name tags

You can "tag" room names by putting a single word after the ending quote:

    "n" : "Maze"central <-> "Maze"north

Both rooms will be built with the name "Maze", but stored on the builder
character as different attributes. Name tags are useful when you're building
things like mazes, or just want to confuse the Players for some reason. :)
Anywhere you can use a room name, you can also use a name tag.

### Custom Code

The DESCRIBE command can be used to add descriptions to rooms:

    DESCRIBE "Grasslands"=The grassy plains stretch on and on.

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

4. (not implemented by *quickbuild*) Lines starting with '\*'
  (in the first column) are treated
  as continuations and are converted from plain ASCII to
  "MUSH-ready" ASCII, i.e. spaces -&gt; %b, \[ -&gt; \[, etc. %r
  characters are prepended to any subsequent &gt; lines.

5. In any other line, each tab is converted to a space.

* * *
# OPTIONS

### --help

Prints a usage summary

### --nobrackets

By default, *quickbuild* assumes that you like the &lt;B&gt;racket style
of exit naming, where the abbreviation in the brackets is the short
name for the exit.

### --noreverse

By default, *quickbuild* assumes that the line REVERSE "a" "b" should
define "b" as the reverse exit of "a", AND "a" as the reverse exit of "b".
Use this option to make REVERSE one-way, and only define
the second argument as the reverse exit of the first argument.

### --config-file <filename>

Use <filename> as the configuration file instead of the default.

### --no-config-file

Don't use any configuration file.

* * *
# CONFIGURATION FILE

By default, *quickbuild* loads a configuration file that defines a few default
aliases for exits (e.g., "n" for "<N>orth;north;nort;nor;no;n") and reverse
exits (e.g. "n" and "s"). It searches for this file in the following order:

1. Given on the command line with --config-file (stop if found)
2. .qbcfg or qb.cfg in the current directory
3. .qbcfg or qb.cfg in the user's home directory

Configuration files are actually just quickbuild files themselves. You can
use the REVERSE and ALIAS line in your building scripts, or even have a
ROOM PARENT line in your default configuration file.

* * *
# EXAMPLE

Here is an example that illustrates most of the features:

### Input

    ROOM ZONE: #123
    ROOM FLAGS: transparent
    EXIT PARENT: #444
    "n": "Town Square" <-> "City Gates"
    "e": "Town Square" <-> "Main Street"
    EXIT FLAGS: opaque
    "<M>anhole;manhole;m;down;dow;do;d": "Main Street" -> "Sewer"
    DESCRIBE "Town Square"=This is town square.
    ON "s" FROM "City Gates"
    @lock s = ok/1
    ENDON

### Resulting Output

    think Digging Rooms
    @dig/teleport Town Square
    @set me=ROOM.Town_Square:%l
    @chzone here=#123
    @set here=transparent
    @describe here=This is town square.
    @dig/teleport City Gates
    @set me=ROOM.City_Gates:%l
    @chzone here=#123
    @set here=transparent
    @dig/teleport Main Street
    @set me=ROOM.Main_Street:%l
    @chzone here=#123
    @set here=transparent
    @dig/teleport Sewer
    @set me=ROOM.Sewer:%l
    @chzone here=#123
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
    @lock s = ok/1
    @teleport [v(ROOM.Main_Street)]
    @open West <W>;west;wes;we;w=[v(ROOM.Town_Square)]
    @parent West <W>=#444
    @open <M>anhole;M;manhole;m;down;dow;do;d=[v(ROOM.Sewer)]
    @parent <M>anhole=#444
    @set <M>anhole=opaque
    think WARNING: Creating room with no exits: Sewer
    @teleport [v(ROOM.Sewer)]


In this silly example, an input of 302 characters resulted in an output of
1163 characters, so you saved considerable typing time.

* * *
# RESTRICTIONS

Exits originating from the same source room must have unique names.

* * *
# AUTHOR

*Quickbuild* was originally coded by Alan Schwartz. The original Perl
version is available here:
    http://download.pennmush.org/Accessories/

The modern Ruby version is authored by Ryan Dowell, and distributed under the
same license as PennMUSH. The latest version of *quickbuild* is available here:
    https://github.com/Sketch/quickbuild
