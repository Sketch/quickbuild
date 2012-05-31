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


# Section: Parse options
options = {}
options[:brackets] = true
options[:brackets_override] = false
options[:debug] = false
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
	opts.on("-d", "--debug", "Show debug output (requires chatchart gem)") do
		options[:debug] = true
	end
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!
# Program exits here if user did --help

# Section: Input file parser
class Action < SimpleAction
	def unhandled_call(state, input, extra)
		return nil if state == :error
	end
end

# ActionWarnIfNotDefault
class ActionWIND < SimpleAction
	def unhandled_call(state, input, extra)
		return nil if state == :error
		return {:state => nil, :action => [[:WARNING, "#{@pattern} matched inside \"#{getstate(state)}\" state."]]} if state != :default
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
syntaxp.push Action.new(/^\s*$/,
	[:default, lambda{|s| [s,[[:NOP]] ]}],
	[:in,      lambda{|s| [s,[[:NOP]] ]}],
	[:on,      lambda{|s| [s,[[:NOP]] ]}] )
syntaxp.push Action.new(/^@@/,
	[:in, lambda{|s| [s,[[:NOP]] ]}],
	[:on, lambda{|s| [s,[[:NOP]] ]}] )

closebracket = lambda {|s,input,e|
	str = (s[:bracketline] == e[:linenumber] - 1) ? '%r' : ''
	str += buffer_escape(input.sub(/^>/,''))
	command = [[:BUFFER_ROOM, s[:roomname], str]] if s[:state] == :IN
	command = [[:BUFFER_EXIT, s[:roomname], s[:exitname], str]] if s[:state] == :ON
	return [s.merge({:bracketline => e[:linenumber]}), command]
}
syntaxp.push Action.new(/^>/,
	[:in, closebracket],
	[:on, closebracket])
syntaxp.push Action.new(/^#.*$/,
	[:default, lambda {|s| [s, [[:NOP]]]}],
	[:in,      lambda {|s,i,e| [s, [[:BUFFER_ROOM, s[:roomname], buffer_prefix(e[:matchdata][0])]] ]}],
	[:on,      lambda {|s,i,e| [s, [[:BUFFER_EXIT, s[:roomname], s[:exitname], buffer_prefix(e[:matchdata][0])]] ]}] )
syntaxp.push ActionWIND.new(/^ATTR BASE:\s*(.*)$/,
	[:default, lambda {|s,i,e| [s, [[:ATTR_BASE, e[:matchdata][1]]] ]}] )
syntaxp.push ActionWIND.new(/^REVERSE\s*:?\s*"(.*)"\s*"(.*)"/i,
	[:default, lambda {|s,i,e| [s, [[:REVERSE, e[:matchdata][1], e[:matchdata][2]]] ]}] )
#syntaxp.push ActionWIND.new(/^ROOM PARENT:\s*(.*)$/) +
#	[:default, lambda {|s,i,e|
#		# Needs differentiation betwen Database reference numbers and names.
#		 [:default, [[:ROOM_PARENT, e[:matchdata][1]]]]
#	}]
syntaxp.push ActionWIND.new(/^"(.*?)"\s*:\s*("(.*?)"(\s*(<?->)\s*"(.*?)")+)$/,
	[:default, lambda {|s,i,e|
		exitname, roomstring = e[:matchdata][1], e[:matchdata][2]
		lastroom = e[:matchdata][3]
		commands = [[:CREATE_ROOM, lastroom]]
		roomstring.scan(/\s*(<?->)\s*"(.*?)"/).each {|match|
			commands.push([:CREATE_ROOM, match[1]])
			commands.push([:CREATE_EXIT, exitname, lastroom, match[1]])
			commands.push([:CREATE_REVERSE_EXIT, exitname, lastroom, match[1]]) if match[0] == "<->"
			lastroom = match[1]
		}
		return {:state => s, :action => commands}
	}])
syntaxp.push ActionWIND.new(/^IN "(.*)"$/,
	[:default, lambda {|s,i,e| [{:state => :in, :roomname => e[:matchdata][1]}, [[:NOP]] ]}] )
syntaxp.push ActionWIND.new(/^ON "(.*)" FROM "(.*)"$/,
	[:default, lambda {|s,i,e| [{:state => :on, :roomname => e[:matchdata][1], :exitname => e[:matchdata][2]}, [[:NOP]] ]}] )
syntaxp.push Action.new(/^ENDIN$/,
	[:in,      lambda {|s,i,e| [:default, [[:NOP]] ]}],
	[:default, lambda {|s,i,e| [:error,   [[:ERROR, "ENDIN outside of IN-block."]] ]}],
	[:on,      lambda {|s,i,e| [:default, [[:WARNING, "ENDIN inside ON-block."]] ]}] )
syntaxp.push Action.new(/^ENDON$/,
	[:on,      lambda {|s,i,e| [:default, [[:NOP]] ]}],
	[:default, lambda {|s,i,e| [:error,   [[:ERROR, "ENDON outside of ON-block."]] ]}],
	[:in,      lambda {|s,i,e| [:default, [[:WARNING, "ENDON inside IN-block."]] ]}] )
syntaxp.push Action.new(/^.+$/,
	[:default, lambda {|s,i,e| [:error, [[:ERROR, "Unrecognized command."]] ]}],
	[:in,      lambda {|s,i,e| [s, [[:BUFFER_ROOM, s[:roomname], buffer_prefix(e[:matchdata][0])]] ]}],
	[:on,      lambda {|s,i,e| [s, [[:BUFFER_EXIT, s[:roomname], s[:exitname], buffer_prefix(e[:matchdata][0])]] ]}] )

#syntaxp.push ActionWIND.new(/^DESC(RIBE)? "(.*?)"
#syntaxp.push Action.new(/^&(\S+)\s+"(.*?)"\s*=(.*)$/) +

def process_file(fileobj, parser)
	extras = {:linenumber => 0}
	commands = []
	while (line = fileobj.gets) do
		extras[:linenumber] += 1
		state, result = parser.invoke(line, extras)
		result.each {|stateresults|
			stateresults.each {|opcode|
				commands.push({:location => {:file => fileobj.path, :linenumber => extras[:linenumber]}, :opcode => opcode})
			}
		}
	end
	return commands
end


# Section: Opcodes -> Graph
#
# Here we read the opcodes from the last section.
# This state machine has states that only affect its output, not input
# processing. This machine is simple enough that a switch will do.
class RoomNode
	attr_accessor :id
	def initialize(id)
		@id = id
		@edges = []
		@properties = {}
	end
	def add_exit(exitedge)
		@edges.push(exitedge)
	end
	def lookup_exit(id)
		return @edges[id]
	end
	def to_s()
		return @id
	end
end

class ExitEdge
	attr_accessor :id, :from_room, :to_room
	def initialize(id, from_room, to_room)
		@id = id
		@from_room = from_room
		@to_room = to_room
		@properties = {}
	end
	def to_s()
		return [@from_room.to_s(), '-->', @to_room.to_s()].join(' ')
	end
end

class MuGraph
	def initialize()
		@nodes = {}
		@edgelist = []
	end
	def [](x)
		return @nodes[x]
	end
	def new_room(id)
		@nodes.store(id, RoomNode.new(id))
	end
	def new_exit(id, from_room, to_room)
		exitedge = ExitEdge.new(id, from_room, to_room)
		from_room.add_exit(exitedge)
		@edgelist.push(exitedge)
	end
	def nodes()
		if block_given? then
			@nodes.values {|node| yield(node)}
		end
		return @nodes.values
	end
	def edges()
		if block_given? then
			@edgelist.each {|exitedge| yield(exitedge)}
		end
		return @edgelist
	end
end

def mywarn(stateobj, message, prefix="WARNING:")
	warn("#{prefix} File '#{stateobj[:location][:file]}' Line #{stateobj[:location][:linenumber]}: #{message.to_s()}")
end
def die(stateobj, message)
	mywarn(stateobj, message, "ERROR:")
	abort
end

# Take an opcode array and output a graph.
def process_opcodes(opcode_array)
	nodelist = []
	edgelist = []
	stateobj = {
		:location => nil,
		:reverse_exits => {},
		:exit_aliases => {},
		:graph => MuGraph.new()
	}
	graph = stateobj[:graph]
	opcode_array.each {|h|
		stateobj[:location] = h[:location]
		operation, *operand = h[:opcode]
		case operation
		when :NOP
			# Do nothing
		when :ERROR
			die(stateobj, operand[0])
		when :WARN
			mywarn(stateobj, operand[0])
		when :REVERSE
			stateobj[:reverse_exits].store(operand[0], operand[1])
		when :CREATE_ROOM # Do not error/warn if it exists.
			graph.new_room(operand[0]) if graph[operand[0]] == nil
		when :CREATE_EXIT
			from_room, to_room = graph[operand[1]], graph[operand[2]]
			die(stateobj, "Room #{operand[1]} doesn't exist") if ! from_room
			die(stateobj, "Room #{operand[2]} doesn't exist") if ! to_room
			graph.new_exit(operand[0], from_room, to_room)
		when :CREATE_REVERSE_EXIT
			from_room, to_room = graph[operand[1]], graph[operand[2]]
			reverse = stateobj[:reverse_exits][operand[0]]
			die(stateobj, "No reverse exit for #{operand[0]}") if ! reverse
			die(stateobj, "Room #{operand[1]} doesn't exist") if ! from_room
			die(stateobj, "Room #{operand[2]} doesn't exist") if ! to_room
			graph.new_exit(reverse, to_room, from_room)
		when :BUFFER_ROOM
			# Warn if room doesn't exist
		when :BUFFER_EXIT
			# Warn if exit doesn't exist
		end
	}
	return graph
end


# Section: Graph -> Softcode
#
# Warn on: unlinked rooms
#
# Print out MUSH code. We do it like this.
# 1. Dig all of the rooms and store their dbrefs
# 2. Visit each room, and, while there:
#    a. Open all of the exits leading from that room, applying exit code
#    b. Apply any room code
# We use attributes on the player to store room dbrefs. We call them
#   #{ATTR_BASE}.#{room.id}. Same for exit dbrefs.
def process_graph(graph)
	rooms = graph.nodes()
	exits = graph.edges()
	# TODO: Sort the nodes so non-chzoned and non-parented rooms come first.
	# They're probably the ZMR/Parent rooms.
	output = ["think Digging Rooms"]
	rooms.each {|roomnode|
		output << "@dig/teleport #{roomnode.id}"
		output << "@set me=ROOM.#{roomnode.id}:%l"
	}
	exits.each {|exitedge|
		output << "@teleport [v(ROOM.#{exitedge.from_room.id})]"
		output << "@open #{exitedge.id}=[v(ROOM.#{exitedge.to_room.id})]"
	}
	return output
end


# Section: Execution
if options[:debug] then
	puts "#{options}"
	puts "#{ARGV}"
end

require 'chatchart' if options[:debug]
if options[:configfilename] then
	# parse config file
end
commandlist = process_file(ARGF,syntaxp)
if options[:debug] then
	commandlist.each {|cmd| puts "#{cmd}" }
end
graph = process_opcodes(commandlist)
if options[:debug] then
	a = []
	graph.edges {|edge| puts edge }
	graph.edges {|edge|
		a.push(edge.from_room.id.intern - edge.to_room.id.intern)
	}
	g = ChatChart::Graph.new << a
	ChatChart::SmartLayout[ g ]
	puts g.to_canvas(ChatChart::L1Line)
end
softcode = process_graph(graph)
puts(softcode)
