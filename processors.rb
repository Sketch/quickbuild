VERSION='2.20'

def buffer_prefix(s)
	return (/^\s+/.match(s) ? "" : "\n") + s.sub(/^\s+/,'').gsub(/\t/,' ')
end

ESCAPE_CHARS = ['\\','$','%','(',')',',',';','[',']','^','{','}',"\r\n", "\n", "\r"]
ESCAPE_WITH = ['\\\\','\\$','\\%','\\(','\\)','\\,','\\;','\\[','\\]','\\^','\\{','\\}','%r','%r','%r']
ESCAPE_REGEXP = Regexp.union(ESCAPE_CHARS)
ESCAPE_HASH = Hash[ESCAPE_CHARS.zip(ESCAPE_WITH)]
def buffer_escape(s)
	return s.gsub(ESCAPE_REGEXP, ESCAPE_HASH)
end

def write_room_buffer
  lambda {|s,i,e| [s, [[:BUFFER_ROOM, s[:roomname], buffer_prefix(e[:matchdata][0])]] ]}
end
def write_exit_buffer
  lambda {|s,i,e| [s, [[:BUFFER_EXIT, s[:roomname], s[:exitname], buffer_prefix(e[:matchdata][0])]] ]}
end

class StateMachine
  def initialize
    @state = {:state => :default}
    @action_table = []
    @warn_room ||= lambda(&method(:warn_during_in_mode))
    @warn_exit ||= lambda(&method(:warn_during_on_mode))
  end

  def invoke(input, extra_info)
    return nil if @state == :error
    input_line = input.strip
    actual_state = @state[:state]
    action = @action_table.detect {|regexp, state, _action| actual_state == state && regexp =~ input_line }

    extra_info.merge!( {:matchdata => Regexp.last_match} )
    ret_state, *operations = action[2].call(@state, input_line, extra_info)
    @state = case ret_state
      when Hash then ret_state
      when Symbol then {:state => ret_state}
      when nil then @state
      end

    return [@state, operations]
  end

  def add_tristate_action(line_matcher, *state_action_pairs)
    @action_table += state_action_pairs.map {|pair| [line_matcher] + pair}
  end

  def add_basestate_action(line_matcher, state_action_pairs)
    @action_table << ([line_matcher] + state_action_pairs)
    @action_table << [line_matcher, :in, @warn_room]
    @action_table << [line_matcher, :on, @warn_exit]
  end

  def warn_during_in_mode(state, input, extra)
		[nil, [
      [:WARNING, "Directive matched inside \"#{state[:state].upcase}\" state: '#{input.rstrip}'"],
      write_room_buffer.call(state, input, extra).last.first
    ]]
  end

  def warn_during_on_mode(state, input, extra)
		[nil, [
      [:WARNING, "Directive matched inside \"#{state[:state].upcase}\" state: '#{input.rstrip}'"],
      write_exit_buffer.call(state, input, extra).last.first
    ]]
  end

end

class InputStateMachine
  attr_reader :machine
  def initialize
    @machine = StateMachine.new
    @machine.add_tristate_action(/^\s*$/,
      [:default, lambda{|s,i,e| [s,[[:NOP]] ]}],
      [:in,      lambda{|s,i,e| [s,[[:NOP]] ]}],
      [:on,      lambda{|s,i,e| [s,[[:NOP]] ]}] )
    @machine.add_tristate_action(/^@@/,
      [:in, lambda{|s,i,e| [s,[[:NOP]] ]}],
      [:on, lambda{|s,i,e| [s,[[:NOP]] ]}] )

    closebracket = lambda {|s,input,e|
      str = (s[:bracketline] == e[:linenumber] - 1) ? '%r' : ''
      str += buffer_escape(input.sub(/^>/,''))
      command = [[:BUFFER_ROOM, s[:roomname], str]] if s[:state] == :IN
      command = [[:BUFFER_EXIT, s[:roomname], s[:exitname], str]] if s[:state] == :ON
      return [s.merge({:bracketline => e[:linenumber]}), command]
    }
    @machine.add_tristate_action(/^>/,
      [:in, closebracket],
      [:on, closebracket])

    @machine.add_tristate_action(/^#.*$/,
      [:default, lambda {|s,i,e| [s, [[:NOP]]]}],
      [:in,      lambda {|s,i,e| [s, [[:BUFFER_ROOM, s[:roomname], buffer_prefix(e[:matchdata][0])]] ]}],
      [:on,      lambda {|s,i,e| [s, [[:BUFFER_EXIT, s[:roomname], s[:exitname], buffer_prefix(e[:matchdata][0])]] ]}] )

    @machine.add_basestate_action(/^ATTR BASE:\s*(.*)$/,
      [:default, lambda {|s,i,e| [s, [[:ATTR_BASE, e[:matchdata][1]]] ]}] )

    @machine.add_basestate_action(/^ALIAS\s*:?\s*(".*")\s*"(.*)"\s*$/i,
      [:default, lambda {|s,i,e| [s, [[:ALIAS, e[:matchdata][1], e[:matchdata][2]]] ]}] )

    @machine.add_basestate_action(/^REVERSE\s*:?\s*(".*")\s*(".*")\s*$/i,
      [:default, lambda {|s,i,e| [s, [[:REVERSE, e[:matchdata][1], e[:matchdata][2]]] ]}] )

    @machine.add_basestate_action(/^ROOM PARENT:\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_PARENT, nil, nil]] ]}] )
    @machine.add_basestate_action(/^ROOM PARENT:\s*(#\d+)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_PARENT, e[:matchdata][1], :raw]] ]}] )
    @machine.add_basestate_action(/^ROOM PARENT:\s*(".*"(?:[^->\s]\S*)?)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_PARENT, e[:matchdata][1], :id]] ]}] )

    @machine.add_basestate_action(/^ROOM ZONE:\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_ZONE, nil, nil]] ]}] )
    @machine.add_basestate_action(/^ROOM ZONE:\s*(#\d+)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_ZONE, e[:matchdata][1], :raw]] ]}] )
    @machine.add_basestate_action(/^ROOM ZONE:\s*(".*"(?:[^->\s]\S*)?)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_ZONE, e[:matchdata][1], :id]] ]}] )

    @machine.add_basestate_action(/^ROOM FLAGS:\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_FLAGS, nil]] ]}] )
    @machine.add_basestate_action(/^ROOM FLAGS:\s*(.+)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:ROOM_FLAGS, e[:matchdata][1]]] ]}] )

    @machine.add_basestate_action(/^EXIT PARENT:\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_PARENT, nil, nil]] ]}] )
    @machine.add_basestate_action(/^EXIT PARENT:\s*(#\d+)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_PARENT, e[:matchdata][1], :raw]] ]}] )
    @machine.add_basestate_action(/^EXIT PARENT:\s*(".*"(?:[^->\s]\S*)?)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_PARENT, e[:matchdata][1], :id]] ]}] )

    @machine.add_basestate_action(/^EXIT ZONE:\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_ZONE, nil, nil]] ]}] )
    @machine.add_basestate_action(/^EXIT ZONE:\s*(#\d+)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_ZONE, e[:matchdata][1], :raw]] ]}] )
    @machine.add_basestate_action(/^EXIT ZONE:\s*(".*"(?:[^->\s]\S*)?)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_ZONE, e[:matchdata][1], :id]] ]}] )

    @machine.add_basestate_action(/^EXIT FLAGS:\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_FLAGS, nil]] ]}] )
    @machine.add_basestate_action(/^EXIT FLAGS:\s*(.+)\s*$/,
      [:default, lambda {|s,i,e| [s, [[:EXIT_FLAGS, e[:matchdata][1]]] ]}] )

    @machine.add_basestate_action(/^(".*?")\s*:\s*((".*?"(?:[^->\s]\S*)?)(\s*(<?->)\s*(".*?"(?:[^->\s]\S*)?))+)\s*$/,
      [:default, lambda {|s,i,e|
        exitname, roomstring = e[:matchdata][1], e[:matchdata][2]
        lastroom = e[:matchdata][3]
        commands = [[:CREATE_ROOM, lastroom]]
        roomstring.scan(/\s*(<?->)\s*(".*?"(?:[^->\s]\S*)?)/).each {|match|
          commands.push([:CREATE_ROOM, match[1]])
          commands.push([:CREATE_EXIT, exitname, lastroom, match[1]])
          commands.push([:CREATE_REVERSE_EXIT, exitname, lastroom, match[1]]) if match[0] == "<->"
          lastroom = match[1]
        }
        return [s, commands]
      }])

    @machine.add_basestate_action(/^IN\s+(".*"(?:[^->\s]\S*)?)\s*$/,
      [:default, lambda {|s,i,e| [{:state => :in, :roomname => e[:matchdata][1]}, [[:NOP]] ]}] )

    @machine.add_basestate_action(/^ON\s+(".*")\s+FROM\s+(".*"(?:[^->\s]\S*)?)\s*$/,
      [:default, lambda {|s,i,e| [{:state => :on, :roomname => e[:matchdata][2], :exitname => e[:matchdata][1]}, [[:NOP]] ]}] )

    @machine.add_tristate_action(/^ENDIN\s*$/,
      [:in,      lambda {|s,i,e| [:default, [[:NOP]] ]}],
      [:default, lambda {|s,i,e| [:error,   [[:ERROR, "ENDIN outside of IN-block."]] ]}],
      [:on,      lambda {|s,i,e| [:default, [[:ERROR, "ENDIN inside of ON-block."]] ]}] )

    @machine.add_tristate_action(/^ENDON\s*$/,
      [:on,      lambda {|s,i,e| [:default, [[:NOP]] ]}],
      [:default, lambda {|s,i,e| [:error,   [[:ERROR, "ENDON outside of ON-block."]] ]}],
      [:in,      lambda {|s,i,e| [:default, [[:ERROR, "ENDON inside of IN-block."]] ]}] )

    @machine.add_basestate_action(/^DESC(?:RIBE)?\s+(".*?"(?:[^=->\s]\S*)?)\s*=\s*(.*)$/,
      [:default, lambda {|s,i,e| [s, [[:BUFFER_ROOM, e[:matchdata][1], "\n@describe here=" + e[:matchdata][2]]] ]}] )

    @machine.add_tristate_action(/^.+$/,
      [:default, lambda {|s,i,e| [:error, [[:ERROR, "Unrecognized command: #{e[:matchdata][0]}"]] ]}],
      [:in,      write_room_buffer],
      [:on,      write_exit_buffer])

    def invoke(*args)
      @machine.invoke(*args)
    end
  end
end


def process_file(file)
  parser = InputStateMachine.new()
	extras = {:linenumber => 0}
	commands = []

	file.each_line do |line|
		extras[:linenumber] += 1
		_state, result = parser.invoke(line, extras)
		result.each {|stateresults|
			stateresults.each {|opcode|
				commands.push({:location => {:file => file.path, :linenumber => extras[:linenumber]}, :opcode => opcode})
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

# think squish(iter(lnum(1,127),if(cand(not(valid(attrname,x[chr(##)]x)),t(chr(##))),chr(##))))
# Invalid ASCII characters in attribute names for:
# PennMUSH : % ( ) : [ \ ] ^ { }
# TinyMUX  : " % * , : ; [ \ ] { | }
# RhostMUSH: " * , : ; [ \ ] { | }
# All combined: " % ( ) * , : ; [ \ ] ^ { | }
#
# Don't rely on these functions producing consistent
# output between versions of quickbuild!
BADATTR_ORDS = [34, 37, 40, 41, 42, 44, 58, 59, 91, 92, 93, 94, 123, 124, 125]
BADATTR_CHARS = (BADATTR_ORDS.map {|x| x.chr() }) + [' ']
BADATTR_REPLACE = (BADATTR_ORDS.map {|x| '$' + x.to_s(16) }) + ['_']
BADATTR_REGEXP = Regexp.union(BADATTR_CHARS)
BADATTR_HASH = Hash[BADATTR_CHARS.zip(BADATTR_REPLACE)]
def mush_attr_escape(s)
	return s.gsub(BADATTR_REGEXP, BADATTR_HASH)
end
def mush_id_format(s)
	return mush_attr_escape(s.sub(/^"/,'').sub(/"$/,''))
end
def id_to_name(id)
	return id.match(/"(.*)"/)[1]
end

def aliasify(given_name, alias_list = [])
	name, _semicolon, given_aliases = given_name.partition(';')
	aliased_word, aliased_name = nil, name
	autobracket = false
	if /<\S+>/ !~ name && autobracket then # Not pre-bracketed
		aliased_word = name.split(' ').reduce('') {|m,w| m.concat(w[0])}
		aliased_name = (name.split(' ').map {|word| word.sub(/^./, '<\0>')}).join(' ')
	elsif /<\S+>/ =~ name then # Pre-bracketed exit name
		aliased_word = name.scan(/<(\S+)>/).join('')
		aliased_name = name
	end
	fullname = ([aliased_name, aliased_word, given_aliases].select {|x| x && x != ''}).join(';')
	return [fullname, [aliased_word] + given_aliases.split(';')]
end

class RoomNode
	attr_accessor :id, :name
	attr_accessor :type
	attr_reader :edges
	attr_accessor :attr_base
	attr_accessor :parent, :parent_type
	attr_accessor :zone, :zone_type
	attr_accessor :flags
	def initialize(id)
		@id = mush_id_format(id)
		@name = id_to_name(id)
		@type = :room
		@edges = {}
		@attr_base = nil
		@parent = nil
		@parent_type = nil
		@zone = nil
		@zone_type = nil
		@flags = nil
		@buffer = ''
		@properties = {}
	end
	def add_exit(exitedge)
		@edges.store(exitedge.id, exitedge)
	end
	def lookup_exit(id)
		return @edges[mush_id_format(id)]
	end
	def to_s()
		return @id
	end
	def set_buffer(s)
		@buffer = s
	end
	def append_buffer(s)
		@buffer.concat(s)
	end
	def buffer()
		@buffer.lstrip
	end
end

class ExitEdge
	attr_accessor :id, :name, :from_room, :to_room
	attr_accessor :parent, :parent_type
	attr_accessor :zone, :zone_type
	attr_accessor :flags
	def initialize(id, name, from_room, to_room)
		@id = mush_id_format(id)
		@name = name
		@parent = nil
		@parent_type = nil
		@zone = nil
		@zone_type = nil
		@flags = nil
		@from_room = from_room
		@to_room = to_room
		@buffer = ''
		@properties = {}
	end
	def to_s()
		return [@from_room.to_s(), '-->', @to_room.to_s()].join(' ')
	end
	def append_buffer(s)
		@buffer.concat(s)
	end
	def buffer()
		@buffer.lstrip
	end
end

class MuGraph
	attr_reader :edgelist
	attr_accessor :id_parents, :id_zones
	def initialize()
		@nodes = {}
		@edgelist = []
		@id_parents = {}
		@id_zones = {}
	end
	def [](x)
		return @nodes[x]
	end
	def new_room(id)
		@nodes.store(id, RoomNode.new(id))
	end
	def new_exit(id, from_room, to_room, aliases = {}, autoalias = true)
		name = aliases[id]
		name ||= aliasify(id_to_name(id))[0] if autoalias
		name ||= id_to_name(id)
		exitedge = ExitEdge.new(id, name, from_room, to_room)
		from_room.add_exit(exitedge)
		@edgelist.push(exitedge)
		return exitedge
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
def process_opcodes(opcode_array, options = {})
	stateobj = {
		:location => nil,
		:attr_base => "ROOM.",
		:reverse_exits => {},
		:exit_aliases => {},
		:room_parent => nil, :room_parent_type => nil,
		:room_zone => nil,   :room_zone_type => nil,
		:room_flags => nil,
		:exit_parent => nil, :exit_parent_type => nil,
		:exit_zone => nil,   :exit_zone_type => nil,
		:exit_flags => nil,
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
		when :WARNING
			mywarn(stateobj, operand[0])

		when :ATTR_BASE
			stateobj[:attr_base] = (operand[0].strip.length == 0 ? "ROOM." : operand[0].strip)

		when :ALIAS
			old = stateobj[:exit_aliases].delete(operand[0])
			mywarn(stateobj, "Replacing alias definition #{operand[0]}->\"#{old}\" with #{operand[0]}->\"#{operand[1]}\".") if old
			stateobj[:exit_aliases].store(operand[0], operand[1])

		when :REVERSE
			old = stateobj[:reverse_exits].delete(operand[0])
			mywarn(stateobj, "Replacing reverse definition #{operand[0]}->#{old} with #{operand[0]}->#{operand[1]}") if old
			stateobj[:reverse_exits].store(operand[0], operand[1])
			if options[:bidirectional_reverse] then
				old = stateobj[:reverse_exits].delete(operand[1])
				mywarn(stateobj, "Replacing reverse definition #{operand[1]}->#{old} with #{operand[1]}->#{operand[0]}") if old
				stateobj[:reverse_exits].store(operand[1], operand[0])
			end

		when :ROOM_PARENT
			if operand[0] && operand[1] == :id then
				room = graph[operand[0]] || # Can return nil
					{:attr_base => stateobj[:attr_base],
					:id => mush_id_format(operand[0]),
					:name => id_to_name(operand[0]),
					:buffer => ''}
				graph.id_parents.store(operand[0], room)
			end
			stateobj[:room_parent_type] = operand[1]
			stateobj[:room_parent] = operand[0]

		when :ROOM_ZONE
			if operand[0] && operand[1] == :id then
				room = graph[operand[0]] || # Can return nil
					{:attr_base => stateobj[:attr_base],
					:id => mush_id_format(operand[0]),
					:name => id_to_name(operand[0]),
					:buffer => ''}
				graph.id_zones.store(operand[0], room)
			end
			stateobj[:room_zone_type] = operand[1]
			stateobj[:room_zone] = operand[0]

		when :ROOM_FLAGS
			stateobj[:room_flags] = operand[0]

		when :EXIT_PARENT
			if operand[0] && operand[1] == :id then
				# Make a room (or thing) if one doesn't exist.
				# Exits typically do not make good exit @parents!
				room = graph[operand[0]] || # Can return nil
					{:attr_base => stateobj[:attr_base],
					:id => mush_id_format(operand[0]),
					:name => id_to_name(operand[0]),
					:buffer => ''}
				graph.id_parents.store(operand[0], room)
			end
			stateobj[:exit_parent_type] = operand[1]
			stateobj[:exit_parent] = operand[0]

		when :EXIT_ZONE
			if operand[0] && operand[1] == :id then
				# Make a room (or thing) if one doesn't exist.
				# Exits typically do not make good exit @parents!
				room = graph[operand[0]] || # Can return nil
					{:attr_base => stateobj[:attr_base],
					:id => mush_id_format(operand[0]),
					:name => id_to_name(operand[0]),
					:buffer => ''}
				graph.id_zones.store(operand[0], room)
			end
			stateobj[:exit_zone_type] = operand[1]
			stateobj[:exit_zone] = operand[0]

		when :EXIT_FLAGS
			stateobj[:exit_flags] = operand[0]

		when :CREATE_ROOM # Do not error/warn if it exists.
			if graph[operand[0]] == nil then
				room = graph.new_room(operand[0])
				room.attr_base = stateobj[:attr_base]
				if stateobj[:room_parent] && operand[0] != stateobj[:room_parent] then
					room.parent = stateobj[:room_parent]
					room.parent_type = stateobj[:room_parent_type]
				end
				if stateobj[:room_zone] && operand[0] != stateobj[:room_zone] then
					room.zone = stateobj[:room_zone]
					room.zone_type = stateobj[:room_zone_type]
				end
				room.flags = stateobj[:room_flags]
				room.set_buffer(graph.id_zones[operand[0]][:buffer]) if graph.id_zones[operand[0]]
				room.set_buffer(graph.id_parents[operand[0]][:buffer]) if graph.id_parents[operand[0]]
			end
			# If we just made a Room Parent/Zone into a real room, make the list reference the real object.
			graph.id_parents.store(operand[0], room) if graph.id_parents.key?(operand[0])
			graph.id_zones.store(operand[0], room) if graph.id_zones.key?(operand[0])

		when :CREATE_EXIT
			from_room, to_room = graph[operand[1]], graph[operand[2]]
			die(stateobj, "Room #{operand[1]} doesn't exist") if ! from_room
			die(stateobj, "Room #{operand[2]} doesn't exist") if ! to_room
			die(stateobj, "There is already an exit #{operand[0]} in room #{operand[1]}") if from_room.lookup_exit(operand[0])
			exitedge = graph.new_exit(operand[0], from_room, to_room, stateobj[:exit_aliases], options[:brackets])
			if stateobj[:exit_parent] then
				exitedge.parent = stateobj[:exit_parent]
				exitedge.parent_type = stateobj[:exit_parent_type]
			end
			if stateobj[:exit_zone] then
				exitedge.zone = stateobj[:exit_zone]
				exitedge.zone_type = stateobj[:exit_zone_type]
			end
			exitedge.flags = stateobj[:exit_flags]

		when :CREATE_REVERSE_EXIT
			from_room, to_room = graph[operand[1]], graph[operand[2]]
			reverse = stateobj[:reverse_exits][operand[0]]
			die(stateobj, "No reverse exit for #{operand[0]}") if ! reverse
			die(stateobj, "Room #{operand[1]} doesn't exist") if ! from_room
			die(stateobj, "Room #{operand[2]} doesn't exist") if ! to_room
			die(stateobj, "There is already an exit #{reverse} in room #{operand[2]} (while making reverse exit for #{operand[0]})") if to_room.lookup_exit(reverse)
			exitedge = graph.new_exit(reverse, to_room, from_room, stateobj[:exit_aliases], options[:brackets])
			if stateobj[:exit_parent] then
				exitedge.parent = stateobj[:exit_parent]
				exitedge.parent_type = stateobj[:exit_parent_type]
			end
			if stateobj[:exit_zone] then
				exitedge.zone = stateobj[:exit_zone]
				exitedge.zone_type = stateobj[:exit_zone_type]
			end
			exitedge.flags = stateobj[:exit_flags]

		when :BUFFER_ROOM
			# We can add a buffer to any room built or guaranteed to be built.
			if graph[operand[0]] then
				graph[operand[0]].append_buffer(operand[1])
			elsif graph.id_parents[operand[0]] then
				graph.id_parents[operand[0]][:buffer] += operand[1]
			elsif graph.id_zones[operand[0]] then
				graph.id_zones[operand[0]][:buffer] += operand[1]
			else
				die(stateobj, "Room #{operand[0]} doesn't exist")
			end

		when :BUFFER_EXIT
			# Exits must be built in a room before they can have a buffer.
			room = graph[operand[0]]
			die(stateobj, "Room #{operand[0]} doesn't exist") if room == nil
			exitedge = room.lookup_exit(operand[1])
			die(stateobj, "Exit #{operand[1]} doesn't exist") if exitedge == nil
			exitedge.append_buffer(operand[2])
		end

	}
	return graph
end


# Section: Graph -> Softcode
#
# TODO: Warn on: Rooms with no entrances
#
# Print out MUSH code. We do it like this:
# 1. Dig all of the rooms and store their database reference numbers. (DBref)
# 2. Visit each room, and, while there:
#    a. Open all of the exits leading from that room, applying exit code
#    b. Apply any room code
# We use attributes on the player to store room dbrefs. We call them
#   #{room.attr_base}#{room.id}.

def wrap_text(initial_tab, tab, text, width = 75)
	return initial_tab + text.scan(/(?:.{1,#{width}})(?:\s+|$)|(?:.{#{width}})/m).join("\n" + tab)
end

def print_room_buffer(roomnode)
	output = []
	if roomnode.buffer != ''
		if roomnode.type == :thing then
			output << "@teleport [v(#{roomnode.attr_base}#{roomnode.id})]=here"
			output << "@teleport [v(#{roomnode.attr_base}#{roomnode.id})]"
		end
		output << roomnode.buffer
		if roomnode.type == :thing then
			output << "@teleport [loc(v(#{roomnode.attr_base}#{roomnode.id}))]"
			output << "@teleport [v(#{roomnode.attr_base}#{roomnode.id})]=me"
		end
	end
	return output
end

def process_graph(graph, options = {})
	abort("Cannot use managed mode with --nosidefx option") if ! options[:unmanaged] && options[:nosidefx]

	output = []
	rooms = graph.nodes()
	rooms.sort! {|a,b|
		next -1 if a.zone == nil && b.zone != nil
		next  1 if a.zone != nil && b.zone == nil
		next -1 if a.parent == nil && b.parent != nil
		next  1 if a.parent != nil && b.parent == nil
		next 0
	}

	now = Time.now
	timestring = ([now.year, now.month, now.day].map {|i| i.to_s.rjust(2,'0')} ).join('-')
	output << "@@ File generated on " + timestring + " with Quickbuild version " + VERSION

	output << wrap_text("@@ ", "@@ ", (graph.edgelist.map {|exitedge| "#{exitedge.from_room.id}-->#{exitedge.to_room.id}" }).join(' '))

	# TODO: Once ATTR_BASES is set on exits, do graph.edgelist.map here.
	attr_bases = (rooms.map {|roomnode| roomnode.attr_base }).sort.uniq
	attr_bases_made = {}
	attr_bases.each {|attrname|
		pieces = attrname.split('`')
		if pieces.length > 1 then
			(0...pieces.length).each {|i|
				attr_base = pieces[0..i].join('`')
				attr_bases_made.store("&" + attr_base + " me=Placeholder", :true)
			}
		end
	}
	if attr_bases_made.length > 0 then
		output << "think Constructing attribute trees (legacy PennMUSH support)"
		output.concat(attr_bases_made.keys)
	end

	unbuilt_parents = graph.id_parents.select {|k,v| v.class == Hash}
	if unbuilt_parents.length > 0 then
		output << "think Creating room & exit parents " + (options[:nosidefx] ? "as rooms" : "as things")
		unbuilt_parents.each {|k,v|
			room = graph.new_room(k)
			room.attr_base = v[:attr_base]
			room.type = :thing
			room.set_buffer(v[:buffer])
			graph.id_parents.store(k, room)
			attrname = "#{room.attr_base}#{room.id}"
			if options[:nosidefx] then
				output << "@dig/teleport #{room.name}"
				output << "@set me=#{attrname}:%l"
			elsif options[:unmanaged] then
					output << "think set(me,#{attrname}:[create(#{room.name},10)])"
			else
					output << "think set(me,#{attrname}:[default(me/#{attrname},create(#{room.name},10))])"
			end
			output << "@lock [v(#{room.attr_base}#{room.id})]= =me"
			output << "@lock/zone [v(#{room.attr_base}#{room.id})]= =me"
			output << "@link [v(#{room.attr_base}#{room.id})]=me"
			output += print_room_buffer(room) if ! rooms.include?(room)
		}
	end

	unbuilt_zones = graph.id_zones.select {|k,v| v.class == Hash}
	if unbuilt_zones.length > 0 then
		output << "think Creating room & exit zones " + (options[:nosidefx] ? "as rooms" : "as things")
		unbuilt_zones.each {|k,v|
			room = graph.new_room(k)
			room.attr_base = v[:attr_base]
			room.type = :thing
			room.set_buffer(v[:buffer])
			graph.id_zones.store(k, room)
			attrname = "#{room.attr_base}#{room.id}"
			if options[:nosidefx] then
				output << "@dig/teleport #{room.name}"
				output << "@set me=#{attrname}:%l"
			elsif options[:unmanaged] then
					output << "think set(me,#{attrname}:[create(#{room.name},10)])"
			else
					output << "think set(me,#{attrname}:[default(me/#{attrname},create(#{room.name},10))])"
			end
			output << "@lock [v(#{room.attr_base}#{room.id})]= =me"
			output << "@lock/zone [v(#{room.attr_base}#{room.id})]= =me"
			output << "@link [v(#{room.attr_base}#{room.id})]=me"
			output += print_room_buffer(room) if ! rooms.include?(room)
		}
	end

	output << "think Digging Rooms"
	rooms.each {|roomnode|
		attrname = "#{roomnode.attr_base}#{roomnode.id}"
		if options[:nosidefx] then
			output << "@dig/teleport #{roomnode.name}"
			output << "@set me=#{attrname}:%l"
		elsif options[:unmanaged] then
			output << "@dig/teleport #{roomnode.name}"
			output << "think set(me,#{attrname}:%l)"
		else
			output << "think set(me,#{attrname}:[default(me/#{attrname},switch(functions(),* DIG *,dig(#{roomnode.name}),create(#{roomnode.name},,r)))])"
			output << "@teleport [v(#{attrname})]"
		end
		if roomnode.parent then
			output << "@parent here=#{roomnode.parent}" if roomnode.parent_type == :raw
			p = graph[roomnode.parent]
			if roomnode.parent_type == :id then
				if options[:nosidefx] then
					output << "@parent here=[v(#{p.attr_base}#{p.id})]"
				else
					output << "think parent(here,[v(#{p.attr_base}#{p.id})])"
				end
			end
		end
		if roomnode.zone then
			output << "@chzone here=#{roomnode.zone}" if roomnode.zone_type == :raw
			z = graph[roomnode.zone]
			output << "@chzone here=[v(#{z.attr_base}#{z.id})]" if roomnode.zone_type == :id
		end
		output << "@set here=#{roomnode.flags}" if roomnode.flags
	}

	output << "think Linking Rooms"
	rooms.each {|roomnode|
		output << "think WARNING: Creating room with no exits: #{roomnode.name}" if roomnode.edges.length == 0
		output << "@teleport [v(#{roomnode.attr_base}#{roomnode.id})]" if roomnode.edges.length > 0 || roomnode.buffer != ''
		roomnode.edges.each {|exitedge_id, exitedge|
			shortname = exitedge.name.partition(';')[0]
			if options[:nosidefx] || options[:unmanaged] then
				output << "@open #{exitedge.name}=[v(#{exitedge.to_room.attr_base}#{exitedge.to_room.id})]"
			else
				output << "@teleport [setr(0,ifelse(t(setr(0,locate(me,#{shortname},eE))),r(0),switch(functions(),* OPEN *,open(#{exitedge.name}),create(#{exitedge.name},,e))))][link(%q0,v(#{exitedge.to_room.attr_base}#{exitedge.to_room.id}))]=here"
			end
			if exitedge.parent then
				output << "@parent #{shortname}=#{exitedge.parent}" if exitedge.parent_type == :raw
				p = graph[exitedge.parent] # Exit parents are not exits
				if exitedge.parent_type == :id then
					if options[:nosidefx] then
						output << "@parent #{shortname}=[v(#{p.attr_base}#{p.id})]"
					else
						output << "think parent(#{shortname},[v(#{p.attr_base}#{p.id})])"
					end
				end
			end
			if exitedge.zone then
				output << "@chzone #{shortname}=#{exitedge.zone}" if exitedge.zone_type == :raw
				p = graph[exitedge.zone] # Exit zones are not exits
				output << "@chzone #{shortname}=[v(#{p.attr_base}#{p.id})]" if exitedge.zone_type == :id
			end
			output << "@set #{shortname}=#{exitedge.flags}" if exitedge.flags
			output << exitedge.buffer if exitedge.buffer != ''
		}
		output += print_room_buffer(roomnode)
	}

	has_entrance = Hash[graph.edgelist.map {|exitedge| [exitedge.to_room, true] }]
	(rooms - has_entrance.keys).each {|roomnode|
		output << "think WARNING: Created room with no entrances: #{roomnode.name}"
	}

	return output
end

def process_file_list_into_softcode(file_list, options={})
  commandlist = file_list.flat_map{|file| process_file(file) }
  graph = process_opcodes(commandlist, options)
  process_graph(graph, options)
end

