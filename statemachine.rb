#!/usr/bin/env ruby
# A simple finite state machine library for line-based text inputs.

# State machines have an ordered list of Actions.
# Actions have a pattern (arg1) and a list of state modifiers (arg2)
# Input is given one line at a time.
# Each Action's pattern is checked against the input line.
# If an Action's pattern matches, and has an entry for the current state,
#  that state modifier is executed. Otherwise, matching proceeds down the list.
#
# The state modifier is called with up to 3 arguments depending on its arity.
# The arguments are, in order: (current_state, input_line, extra_information)
# * current_state is a hash with (user-defined) state information, and
#   the :state key is used to compare if an Action's state entry matches.
# * input_line is the current input.
# * extra_information is a hash of user-defined key-value pairs. It also has a
#   :matchdata key, which is the MatchData for the Action's matched pattern.
#
# State modifiers return [new_state, command_list]. New_state can be
# a :symbol, or a hash with a :state => desired_state. Command_list is
# a list of [:command_name, argument1, argument2, ...]. Exactly what these
# mean is up to the application.


# A flexible default action class.
#
# Define results with + [:state, lambda {|state,input,extras| [:return_state, action_list]}]
#
# Example:
# my_act = SimpleAction.new(/^STATE: RED$/) + [:default, -> {[:red, nil]}]
#
# Now my_act.invoke(:default) returns [:red, nil].
# Push a bunch of actions into a StateMachine to make it work.
#
# Notes:
# Patterns are only required to define .match. 
# If you DO make pattern-matching code more useful than regexps, give me a call.
# Default action is to return nil silently. Define 'unhandled_call(state, input, extra)' to override.
# + [:statename, lambda] is basically syntactic sugar for obj.define_singleton_method('state_statename', lambda)
class SimpleAction
	attr_accessor :pattern
	def initialize(pattern, *args)
		pattern.match('Test string') # Test and fail if ! respond_to?(:match)
		@pattern = pattern
		args.each {|arg| self + arg}
	end
	def getstate(obj)
		case obj
		when Array then obj[0]
		when Hash then obj[:state]
		when Symbol then obj
		when String then obj
		else obj
		end
	end
	def invoke(state, input, extra = nil)
		userfun = ('state_' + (getstate(state).to_s)).intern
		func = nil
		func ||= (respond_to?(userfun) && method(userfun))
		func ||= (respond_to?(:unhandled_call) && method(:unhandled_call))
		return nil if ! func
		args = (func.arity < 0) ? [state, input, extra] : [state, input, extra].slice(0,func.arity)
		return func.call(*args)
	end
	def match (str)
		return @pattern.match(str)
	end
	def + (a)
		raise TypeError, "Expected array, got #{a.class}" if a.class != Array
		self.define_singleton_method('state_' + (getstate(a[0]).to_s), a[1])
		return self
	end
end

# Class: StateMachine
# Use .push() to push actions into the state machine.
# StateMachine is FIFO for pattern matching.
# 
# States can be a symbol or string, but most often they are a hash with a
# :state key that is the state. Only the state[:state] value is matched
# against the action list, but the whole state object is passed to the
# action function.
#
# Supports fallthrough (invoke returns nil), but cannot simultaneously fallthrough and change state.
class StateMachine
	attr_accessor :actions, :state
	def initialize(state = nil)
		@actions = []
		@state = state
	end
	def invoke(input, extra = {}, input_state = nil)
		input_state ||= @state
		reduction =
		(@actions.select {|a| a.match(input)}).reduce({:state => nil, :actions => []}) {|memo,action|
			if memo[:state] == nil then
				result = action.invoke(input_state, input, extra.merge({:matchdata => action.match(input)}))
				case result
				when Array
					memo[:state] = result[0]
					memo[:actions].push(result[1])
				when Hash
					memo[:state] = result[:state]
					memo[:actions].push(result[:action])
				when nil
				else
					raise TypeError, "Invalid return from action: #{result}"
				end
			end
			memo
		}
		@state = reduction[:state] || @state
#		puts "State: #{@state}, Actionlist: #{reduction[:actions]}"
		return [@state, reduction[:actions]]
	end
	def push(action)
		raise TypeError if ! action.respond_to?(:invoke) # Fail early.
		@actions.push(action)
	end
	def to_s()
		return "State: #{@state}"
	end
end
