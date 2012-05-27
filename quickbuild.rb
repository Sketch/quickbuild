#!/usr/bin/env ruby
# Quickbuild - MUSH building tool.
# Original Quickbuild authored by Alan Schwartz, 1999
# Improved, Ruby version by Ryan Dowell, Sketch@M*U*S*H, 2012
# Released under the same license terms as PennMUSH
#
# Usage: quickbuild < infile > output.txt
# Then upload output.txt to a MUSH.
#
# Quickbuild file syntax:
#
# # Comment
# alias "Exit Name" "alias list;separated by;semicolons"
# reverse "Exit Name" "Return Exit Name"
# "Exit Name" : "Source Room Name" -> "Dest Room Name"
# "Exit Name" : "Source Room Name" <-> "Dest Room Name"
# ATTR BASE: <attribute>
# ROOM FLAGS: <flag list>
# ROOM ZONE: <dbref> or "Room Name"
# ROOM PARENT: <dbref> or "Room Name"
# EXIT FLAGS: <flag list>
# EXIT ZONE: <dbref> or "Room Name" (no, that's not an error)
# EXIT PARENT: <dbref> or "Room Name" (no that's not an error)
# DESC "Room Name" = Description
# IN "Room Name"
# ... MUSH code in mpp format ...
# ENDIN
# ON "Exit Name" FROM "Source Room"
# ... MUSH code in mpp format ...
# ENDON
#

VERSION='2.00'

require 'optparse'
require './statemachine.rb'

def DEBUG(s)
	puts "DEBUG: #{s}" if $DEBUG
end

class Action < SimpleAction
	def unhandled_call(state, input, extra)
		return nil if state == :error
	end
end

# ActionWarnIfNotDefault
class ActionWIND < SimpleAction
	def unhandled_call(state, input, extra)
		return nil if state == :error
		return {:state => nil, :action => [[:WARNING, extra[:linenumber], "#{@pattern} matched inside \"#{getstate(state)}\" state."]]} if state != :default
	end	
end

def buffer_prefix(s)
	return (/^\s+/.match(s) ? "\n" : '') + s.sub(/^\s+/,'').gsub(/\t/,' ')
end

ESCAPE_CHARS = ['\\','$','%','(',')',',',';','[',']','^','{','}',"\r\n", "\n", "\r"]
ESCAPE_WITH = ['\\\\','\\$','\\%','\\(','\\)','\\,','\\;','\\[','\\]','\\^','\\{','\\}','%r','%r','%r']
ESCAPE_REGEXP = Regexp.union(ESCAPE_CHARS)
ESCAPE_HASH = Hash[ESCAPE_CHARS.zip(ESCAPE_WITH)]
def buffer_escape(s)
	return s.gsub(ESCAPE_REGEXP, ESCAPE_HASH)
end

syntaxp = StateMachine.new(:default)
syntaxp.push Action.new(/^\s*$/) +
	[:default, lambda{|s| [s,[[:NOP]] ]}] +
	[:in,      lambda{|s| [s,[[:NOP]] ]}] +
	[:on,      lambda{|s| [s,[[:NOP]] ]}]
syntaxp.push Action.new(/^@@/) +
	[:in, lambda{|s| [s,[[:NOP]] ]}] +
	[:on, lambda{|s| [s,[[:NOP]] ]}]

closebracket = lambda {|s,input,e|
	str = (s[:bracketline] == e[:linenumber] - 1) ? '%r' : ''
	str += buffer_escape(input.sub(/^>/,''))
	command = [[:BUFFER_ROOM, s[:roomname], str]] if s[:state] == :IN
	command = [[:BUFFER_EXIT, s[:roomname], s[:exitname], str]] if s[:state] == :ON
	return [s.merge({:bracketline => e[:linenumber]}), command]
}
syntaxp.push Action.new(/^>/) +
	[:in, closebracket] +
	[:on, closebracket]
syntaxp.push Action.new(/^#.*$/) +
	[:default, lambda {|s| [s, [[:NOP]]]}] +
	[:in,      lambda {|s,i,e| [s, [[:BUFFER_ROOM, s[:roomname], buffer_prefix(e[:matchdata][0])]] ]}] +
	[:on,      lambda {|s,i,e| [s, [[:BUFFER_EXIT, s[:roomname], s[:exitname], buffer_prefix(e[:matchdata][0])]] ]}]
syntaxp.push ActionWIND.new(/^ATTR BASE:\s*(.*)$/) +
	[:default, lambda {|s,i,e| [s, [[:ATTR_BASE, e[:matchdata][1]]] ]}]
#syntaxp.push ActionWIND.new(/^ROOM PARENT:\s*(.*)$/) +
#	[:default, lambda {|s,i,e|
#		# Needs differentiation betwen Database reference numbers and names.
#		 [:default, [[:ROOM_PARENT, e[:matchdata][1]]]]
#	}]
syntaxp.push ActionWIND.new(/^"(.*?)"\s*:\s*("(.*?)"(\s*(<?->)\s*"(.*?)")+)$/) +
	[:default, lambda {|s,i,e|
		exitname, roomstring = e[:matchdata][1], e[:matchdata][2]
		lastroom = e[:matchdata][3]
		commands = [[:CREATE_ROOM, lastroom]]
		roomstring.scan(/\s*(<?->)\s*"(.*?)"/).each {|match|
			commands.push([:CREATE_ROOM, match[1]])
			commands.push([:CREATE_EXIT, exitname, lastroom, match[1]])
			commands.push([:CREATE_REVERSE_EXIT, exitname, lastroom, match[1]]) if match[0] == "<->"
		}
		return {:state => s, :action => commands}
	}]
syntaxp.push ActionWIND.new(/^IN "(.*)"$/) +
	[:default, lambda {|s,i,e| [{:state => :in, :roomname => e[:matchdata][1]}, [[:NOP]] ]}]
syntaxp.push ActionWIND.new(/^ON "(.*)" FROM "(.*)"$/) +
	[:default, lambda {|s,i,e| [{:state => :on, :roomname => e[:matchdata][1], :exitname => e[:matchdata][2]}, [[:NOP]] ]}]
syntaxp.push Action.new(/^ENDIN$/) +
	[:in,      lambda {|s,i,e| [:default, [[:NOP]] ]}] +
	[:default, lambda {|s,i,e| [:error,   [[:ERROR, e[:linenumber], "ENDIN outside of IN-block."]] ]}] +
	[:on,      lambda {|s,i,e| [:default, [[:WARNING, e[:linenumber], "ENDIN inside ON-block."]] ]}]
syntaxp.push Action.new(/^ENDON$/) +
	[:on,      lambda {|s,i,e| [:default, [[:NOP]] ]}] + 
	[:default, lambda {|s,i,e| [:error,   [[:ERROR, e[:linenumber], "ENDON outside of ON-block."]] ]}] +
	[:in,      lambda {|s,i,e| [:default, [[:WARNING, e[:linenumber], "ENDON inside IN-block."]] ]}]
syntaxp.push Action.new(/^.+$/) +
	[:default, lambda {|s,i,e| [:error, [[:ERROR, e[:linenumber], "Unrecognized command."]] ]}] +
	[:in,      lambda {|s,i,e| [s, [[:BUFFER_ROOM, s[:roomname], buffer_prefix(e[:matchdata][0])]] ]}] +
	[:on,      lambda {|s,i,e| [s, [[:BUFFER_EXIT, s[:roomname], s[:exitname], buffer_prefix(e[:matchdata][0])]] ]}]

#syntaxp.push ActionWIND.new(/^DESC(RIBE)? "(.*?)"
#syntaxp.push Action.new(/^&(\S+)\s+"(.*?)"\s*=(.*)$/) +


# Section: Parse options
options = {}
options[:brackets] = true
options[:brackets_override] = false
options[:configfilename] = 'sample.cfg'

OptionParser.new do |opts|
	opts.banner = <<EOT.split(/\n/).join('\n')
Quickbuild v#{VERSION}    - offline MUSH building tool
Released under the same terms as PennMUSH

Quickbuild is a ruby script that lets you quickly lay out a MUSH area
(a set of rooms connected by exits, optionally zoned and/or parented)
in an easy-to-use format. It converts this file into uploadble MUSH
code. It's smart about cardinal directions (aliases and reverse exits),
<b>racket style, and a few other things.

Usage: quickbuild.rb [options] inputfile > outfile.txt
EOT
	opts.on("--config-file <filename>", String, "Use <filename> as the configuration file instead of the default.") do |c|
		options[:configfilename] << c
	end
	opts.on("--no-config-file", "Don't use any configuration file.") do
		options[:configfilename] = nil
	end
	opts.on("-b", "--nobrackets", "Don't use <B>racket style of exit naming.") do |b|
		options[:brackets] = !b
		options[:brackets_override] = true
	end
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!
# Program exits here if user did --help

DEBUG "#{options}"
DEBUG "#{ARGV}"

# Section: Main program
if options[:configfilename] then
	# parse config file
end

def parsefile(fileobj, parser)
	state = :default
	extras = {:linenumber => 0}
	commands = []
	while (line = fileobj.gets) do
		extras[:linenumber] += 1
		DEBUG "Old state/line: #{state} / #{line}"
		state, result = parser.invoke(line, extras)
		DEBUG "New state/Actions: #{state} / #{result}"
		result.each {|stateresults| commands += stateresults }
	end
	return commands
end

commandlist = parsefile(ARGF,syntaxp)
commandlist.each {|cmd| puts "#{cmd}" }

  # Print out MUSH code. We do it like this.
  # 1. Dig all of the rooms and store their dbrefs
  # 2. Visit each room, and, while there:
  #    a. Open all of the exits leading from that room, applying exit code
  #    b. Apply any room code
  # We attributes on the player to store room dbrefs. We call them
  #   $base<##>. Same for exit dbrefs.
#  my %room_attrs;
  # 1. Dig all rooms and track their dbrefs. 
  #   To avoid sync problems, we use: @dig/tel room and @set me=$base<##>:%l
  # Sort the rooms so that we dig those rooms without parents/zones first,
  # as these are the ZMRs/Parent rooms. 
