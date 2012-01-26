#!/usr/bin/env ruby

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
	def initialize(pattern)
		# raise TypeError if ! pattern.respond_to(:match)
		pattern.match('Test string')
		@pattern = pattern
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
		userfun = 'state_'.concat(getstate(state).to_s).intern
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
		self.define_singleton_method('state_'.concat(getstate(a[0]).to_s), a[1])
		return self
	end
end

# Class: StateMachine
# Use .push() to push actions into the state machine.
# StateMachine is FIFO for pattern matching.
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
end
