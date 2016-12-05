# Quickbuild

## What is Quickbuild?

*Quickbuild* is a tool that lets you quickly lay out and build a MUSH area.
*Quickbuild* transforms a file containing lines of building instructions
(described in detail below) into the necessary MUSH softcode to build those
rooms. The building instructions are very compact, enabling huge or intricate
grids to be built with little effort.

*Quickbuild* has many useful features:
- It can maintain and modify areas it already built.
- It easily handles grids containing hundreds of rooms.
- It allows zoning and parenting of rooms.
- It's smart about cardinal directions (aliases and reverse exits).
- It automatically handles &lt;b&gt;racket style exit-naming.

*Quickbuild* is a very simple Ruby script: It has no dependencies, and can be
run on any Ruby 1.9.3 or higher without installing gems or libraries.  It
accepts a list of filenames as arguments, and outputs uploadable MUSH code.

## Why would I want to use Quickbuild?
Even when one is very practiced with building commands (@dig, @open, @link, and @describe), building a grid by hand can be very time-consuming and error-prone. *Quickbuild* takes a lot of the manual labor out. Building a suite of connected rooms is easy, and when using *Quickbuild* most of the typing one will do is writing @describes.
Further, if the same builder character is used for each building task, *Quickbuild* files can be used to UPDATE the grid! *Quickbuild* thusly eases the management of huge grids. *Quickbuild* will even let you break sections of the MUSH grid into separate files!

## How do I use Quickbuild?

### Abstract
Large grids are typically a mesh of grids with consistently-named exits linking them.  Although even if you're working with a grid that is not an actual grid of rooms, *Quickbuild* could be useful to you just because it makes maintenance of MUSH grids a lot easier.
However, let us continue with the assumption that the grid is indeed in a grid-like shape. The way that *Quickbuild* expects you to write out your grid is by writing down each series of adjacent rooms. Imagine drawing horizontal and vertical lines through all the rooms in your grid. First, pick the direction of travel, then list all the rooms in that direction. Each room listed in a line will be linked together.

### Basic examples:
Each line of a *Quickbuild* input file is the direction of an exit ("s"), followed by a colon, followed by the names of rooms separated by either -&gt; (for one-way exits) or &lt;-&gt; (for two-way exits). For example, the line:

    "e" : "Blue" -> "Green" -> "Yellow"

Would make a series of rooms that you could only travel eastward toward "yellow" through. The shape of the grid structure would look much like:

    Blue-->Green-->Yellow


An example of a grid in the shape of a C would be:

    "e" : "Blue" <-> "Green" <-> "Yellow"
    "s" : "Blue" <-> "Indigo" <-> "Purple"
    "e" : "Purple" <-> "Red" <-> "Infrared"

Which would look like:

    Blue --- Green --- Yellow
    |
    Indigo
    |
    Purple -- Red --- Infrared


To build a three-by-three cardinal directions grid, one could make the following input file:

    "e" : "Ruby Corner" <-> "Amber Court" <-> "Citrine Fields"
    "e" : "Red Plateu" <-> "Golden Valley" <-> "Yellow Plateu"
    "e" : "Dusk Palace" <-> "Ember Court" <-> "The Pale Sector"

    "s" : "Ruby Corner" <-> "Red Plateu" <-> "Dusk Palace"
    "s" : "Amber Court" <-> "Golden Valley" <-> "Ember Court"
    "s" : "Citrine Fields" <-> "Yellow Plateu" <-> "The Pale Sector"

This would make a grid that is built in the shape of the structure below:

    "Ruby Corner" ---  "Amber Court"  --- "Citrine Fields"
         |                   |                   |
         |                   |                   |
    "Red Plateu"  --- "Golden Valley" --- "Yellow Plateu"
         |                   |                   |
         |                   |                   |
    "Dusk Palace" ---  "Ember Court"  --- "The Pale Sector"

Creating very large grids is simple with *Quickbuild*. While *Quickbuild* does excel at making large structures with many reciprocal exits, making shops off the main grid and wholly non-cardinal grids is also easy!

* * *

# INSTALLATION

If you don't have Ruby installed, you'll need it.
Quickbuild requires Ruby 1.9.3 or greater.

Windows: I recommend http://rubyinstaller.org/ . Associate .rb files
with the Ruby interpreter. Select "Start Command Prompt with Ruby" in
the Start menu.

Linux and OS X: I recommend http://rvm.io/ , even for OSes that have a Ruby
in their package manager. Open a terminal and install RVM, then install a
Ruby using RVM.

Once you've installed Ruby, either git clone or download and unzip Quickbuild
into a directory of your choosing. You can download Quickbuild before you
install Ruby if you want; The order doesn't actually matter.

# USAGE

In your Ruby-enabled terminal, use `cd <directory quickbuild is in>` to change
the directory you're in, and you should be able to print out the example
script by doing `quickbuild.rb test_readme.qb`. To output to a file instead,
use `quickbuild.rb test_readme.qb > output.txt`

Generic syntax is:
`quickbuild.rb [options] inputfile1 [inputfile2 [...]] > output.txt`

* * *
## Quickbuild File Format

An input file for *Quickbuild* can include the following:

### Comments

Lines beginning with # are considered comments and ignored.
In an IN or ON section (see <a href="#custom-code">Custom Code</a>),
no lines are ignored.

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

### Prebuilt rooms

Quickbuild can be used to maintain areas on a MUSH. In those cases,
it's likely that you've already built room parents, or rooms that the
area will be attached to. To make reference to an object already on
the MUSH, use the PREBUILT directive:

    PREBUILT "Shifting Maze Entrance" = #1244
    PREBUILT "Colorful Room Parent" = #222

The name in quotes can then be used as a reference to that object in the
building directives that follow.  The name is not required to be the actual
name of the object on the MUSH.

### Dbref storage

When rooms are built, their dbrefs are stored on the building player
using attributes with names like `ROOM.<room_name>`. If a room has a tag,
the attribute will look like `ROOM.<room_name>$22<tag_name>`. When storing
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

*Quickbuild* will generate @chzone commands to set	the zone of any rooms
defined after the ROOM ZONE: command. You may use additional ROOM ZONE:
commands to change the active room zone. Note that a room is defined when
it is first used in the input. Even if you use a room name again later, the
room's parent/zone will be the first parent/zone it was defined under.

In the same way, you can set default exit zones, room parents, and exit parents
with EXIT ZONE:, ROOM PARENT:, and EXIT PARENT: commands. If you specify
a zone or parent by name and do not include it in any building instructions,
the object will be built as a Thing on the MUSH.  When adding Custom Code
(see <a href="#custom-code">Custom Code</a>)
to an object built as a Thing, address the
thing with "here". In example: "`@aenter here=@pemit %#=You arrive in %n.`".

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
    ...MUSH commands...
    ENDIN

You can add custom code that will be executed near a given exit like this:

    ON "Exit Name" FROM "Source Room Name"
    ...MUSH commands...
    ENDON

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

### --destructive

By default, *Quickbuild* will not change the destination of any exits.
However, that behavior can lead to exits not pointing to where they should.
Use this option to make *Quickbuild* generate code to destroy all exits
in a room before building new ones.
Rooms specified by PREBUILT directive will not have their exits destroyed;
Be sure to adjust the exit destinations from PREBUILT rooms manually if
their destinations should be changed.
These errors will appear when using this flag, and can be ignored:

- PennMUSH:  "Exits can only be teleported to other rooms."
- RhostMUSH: "That's terrific, but what should I do with the list?"
- TinyMUX:   "Unrecognized switch ‘inline’ for command ‘@dolist’."

NOTE: This option requires managed mode, and depends on the codebase having both tel() and destroy().

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
  `@chzone *=*` --> `@zone/purge %0 <newline> @zone/add %0=%1`
- PennMUSH 1.8.5p3 or newer. Some PennMUSH patchlevel between
  1.8.3p13 and 1.8.5p3 fixed locate().  If you determine the minimum
  patchlevel, please let me know.

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
