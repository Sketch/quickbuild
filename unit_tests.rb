#!/usr/bin/env ruby
require 'byebug'
require 'minitest/autorun'
require 'stringio'
require_relative 'processors'

class FakeFile < StringIO
  def path
    'InMemoryTestFile'
  end
end

module Directives
  def command_comment_line
    add_conversion_expectation [1], [[:NOP]], "# Comment lines begin with a pound."
  end

  def command_attr_base
    str = "juniper_town"
    add_conversion_expectation [1], [[:ATTR_BASE, str]], "ATTR BASE: #{str}"
  end

  def command_alias
    str1 = "S"
    str2 = "South"
    add_conversion_expectation [1], [[:ALIAS, "\"#{str1}\"", str2]], "ALIAS \"#{str1}\" \"#{str2}\""
  end

  def command_reverse
    add_conversion_expectation [1], [[:REVERSE, '"Ana"', '"Kata"']], 'REVERSE "Ana" "Kata"'
  end

  def command_room_parent_reset
    add_conversion_expectation [1], [[:ROOM_PARENT, nil, nil]], 'ROOM PARENT:'
  end

  def command_room_parent_raw
    add_conversion_expectation [1], [[:ROOM_PARENT, '#4', :raw]], 'ROOM PARENT: #4'
  end

  def command_room_parent_id
    add_conversion_expectation [1], [[:ROOM_PARENT, '"Orchard"', :id]], 'ROOM PARENT: "Orchard"'
  end

  def command_room_zone_reset
    add_conversion_expectation [1], [[:ROOM_ZONE, nil, nil]], 'ROOM ZONE:'
  end

  def command_room_zone_raw
    add_conversion_expectation [1], [[:ROOM_ZONE, '#5', :raw]], 'ROOM ZONE: #5'
  end

  def command_room_zone_id
    add_conversion_expectation [1], [[:ROOM_ZONE, '"Lilac"', :id]], 'ROOM ZONE: "Lilac"'
  end

  def command_room_flags_reset
    add_conversion_expectation [1], [[:ROOM_FLAGS, nil]], 'ROOM FLAGS:'
  end

  def command_room_flags_set
    str = "TRANSPARENT"
    add_conversion_expectation [1], [[:ROOM_FLAGS, str]], "ROOM FLAGS: #{str}"
  end


  def command_exit_parent_reset
    add_conversion_expectation [1], [[:EXIT_PARENT, nil, nil]], 'EXIT PARENT:'
  end

  def command_exit_parent_raw
    add_conversion_expectation [1], [[:EXIT_PARENT, '#6', :raw]], 'EXIT PARENT: #6'
  end

  def command_exit_parent_id
    add_conversion_expectation [1], [[:EXIT_PARENT, '"Daisy"', :id]], 'EXIT PARENT: "Daisy"'
  end

  def command_exit_zone_reset
    add_conversion_expectation [1], [[:EXIT_ZONE, nil, nil]], 'EXIT ZONE:'
  end

  def command_exit_zone_raw
    add_conversion_expectation [1], [[:EXIT_ZONE, '#7', :raw]], 'EXIT ZONE: #7'
  end

  def command_exit_zone_id
    add_conversion_expectation [1], [[:EXIT_ZONE, '"Aster"', :id]], 'EXIT ZONE: "Aster"'
  end

  def command_exit_flags_reset
    add_conversion_expectation [1], [[:EXIT_FLAGS, nil]], 'EXIT FLAGS:'
  end

  def command_exit_flags_set
    str = "TRANSPARENT"
    add_conversion_expectation [1], [[:EXIT_FLAGS, str]], "EXIT FLAGS: #{str}"
  end

  def command_prebuilt_room
    add_conversion_expectation [1], [[:PREBUILT_ROOM, '"Rose"', '#11']], 'PREBUILT "Rose" = #11'
  end

  def command_describe
    str1 = "Serene Town"
    str2 = "A peaceful place"
    add_conversion_expectation [1], [[:BUFFER_ROOM, "\"#{str1}\"", "\n@describe here=\"#{str2}\""]], "DESCRIBE \"#{str1}\"=\"#{str2}\""
  end

  def command_in
    add_conversion_expectation [1,2,3], [
      [:NOP],
      [:BUFFER_ROOM, '"Golden Land"', "\n@describe here=A beautiful place."],
      [:NOP]
    ], <<-EOS
      IN "Golden Land"
      @describe here=A beautiful place.
      ENDIN
EOS
  end

  def command_on
    add_conversion_expectation [1,2,3], [
      [:NOP],
      [:BUFFER_EXIT, '"Ashen Land"', '"Palace"', "\n@describe here=A wonderous place."],
      [:NOP]
    ], <<-EOS
      ON "Palace" FROM "Ashen Land"
      @describe here=A wonderous place.
      ENDON
EOS
  end

  def command_in_with_comment
    add_conversion_expectation [1,2,3,4], [
      [:NOP],
      [:BUFFER_ROOM, '"Emerald Pillar"', "\n@describe here=A tower of carved emerald."],
      [:BUFFER_ROOM, '"Emerald Pillar"', "\n# Uh-oh."],
      [:NOP]
    ], <<-EOS
      IN "Emerald Pillar"
      @describe here=A tower of carved emerald.
      # Uh-oh.
      ENDIN
EOS
  end

  def command_on
    add_conversion_expectation [1,2,3,4], [
      [:NOP],
      [:BUFFER_EXIT, '"Galaxy Gateway"', '"Portal 5"', "\n@describe here=The stars are calling!"],
      [:BUFFER_EXIT, '"Galaxy Gateway"', '"Portal 5"', "\n# Oh no!"],
      [:NOP]
    ], <<-EOS
      ON "Portal 5" FROM "Galaxy Gateway"
      @describe here=The stars are calling!
      # Oh no!
      ENDON
EOS
  end

  def command_one_way_construction
    add_conversion_expectation [1,1,1], [
      [:CREATE_ROOM, '"In the Fire"'],
      [:CREATE_ROOM, '"Rising in Smoke"'],
      [:CREATE_EXIT, '"burn"', '"In the Fire"', '"Rising in Smoke"'],
    ], '"burn" : "In the Fire" -> "Rising in Smoke"'
  end

  def command_one_way_construction_extended
    add_conversion_expectation [1,1,1,1,1], [
      [:CREATE_ROOM, '"In the Fire"'],
      [:CREATE_ROOM, '"Rising in Smoke"'],
      [:CREATE_EXIT, '"burn"', '"In the Fire"', '"Rising in Smoke"'],
      [:CREATE_ROOM, '"Away in The Breeze"'],
      [:CREATE_EXIT, '"burn"', '"Rising in Smoke"', '"Away in The Breeze"']
    ], '"burn" : "In the Fire" -> "Rising in Smoke" -> "Away in The Breeze"'
  end

  def command_two_way_construction
    add_conversion_expectation [1,1,1,1], [
      [:CREATE_ROOM, '"Green Zone"'],
      [:CREATE_ROOM, '"Blue Zone"'],
      [:CREATE_EXIT, '"shorter"', '"Green Zone"', '"Blue Zone"'],
      [:CREATE_REVERSE_EXIT, '"shorter"', '"Green Zone"', '"Blue Zone"'],
    ], '"shorter" : "Green Zone" <-> "Blue Zone"'
  end

  def command_two_way_construction_extended
    add_conversion_expectation [1,1,1,1,1,1,1], [
      [:CREATE_ROOM, '"Green Zone"'],
      [:CREATE_ROOM, '"Blue Zone"'],
      [:CREATE_EXIT, '"shorter"', '"Green Zone"', '"Blue Zone"'],
      [:CREATE_REVERSE_EXIT, '"shorter"', '"Green Zone"', '"Blue Zone"'],
      [:CREATE_ROOM, '"Ultraviolet Zone"'],
      [:CREATE_EXIT, '"shorter"', '"Blue Zone"', '"Ultraviolet Zone"'],
      [:CREATE_REVERSE_EXIT, '"shorter"', '"Blue Zone"', '"Ultraviolet Zone"'],
    ], '"shorter" : "Green Zone" <-> "Blue Zone" <-> "Ultraviolet Zone"'
  end
end

class UnitTests < MiniTest::Unit::TestCase
  include Directives
  instance_methods.
    select {|name| /^command_/ =~ name}.
    each {|sym| alias_method "test_#{sym.to_s}", sym}

  def make_fakefile(lines)
    FakeFile.new(lines.gsub(/^ */, ''))
  end

  def add_conversion_expectation(steps, instruction_array, string)
    incrementer = steps.to_enum
    fakefile = make_fakefile(string)
    output = process_file(fakefile)
    expected = instruction_array.map {|opcode|
      {:location => {:file => fakefile.path, :linenumber => incrementer.next}, :opcode => opcode}
    }
    assert_equal expected, output
  end

  def test_invalid_command
    bogusness = 'ZOP BOB B-DOWOP BEZAM BAM BOOM'
    add_conversion_expectation [1], [[:ERROR, "Unrecognized command: #{bogusness}"]], "#{bogusness}"
  end

  def test_invalid_endin_outside_in_block
    add_conversion_expectation [1], [[:ERROR, 'ENDIN outside of IN-block.']], 'ENDIN'
  end

  def test_invalid_endon_outside_on_block
    add_conversion_expectation [1], [[:ERROR, 'ENDON outside of ON-block.']], 'ENDON'
  end

  def test_invalid_endon_inside_in_block
    add_conversion_expectation [1,2], [
      [:NOP],
      [:ERROR, 'ENDON inside of IN-block.']
    ], <<-EOS
      IN "Desert"
      ENDON
EOS
  end

  def test_invalid_endin_inside_on_block
    add_conversion_expectation [1,2], [
      [:NOP],
      [:ERROR, 'ENDIN inside of ON-block.']
    ], <<-EOS
      ON "Accelerator" FROM "Tube Station"
      ENDIN
EOS
  end

  def test_blank_line
    add_conversion_expectation [1], [[:NOP]], "\n"
  end

  def test_whitespace_line
    add_conversion_expectation [1], [[:NOP]], "\t "
  end

  # TODO:
  #  Add warning for using a REVERSE exit before its definition.
end

class MultilineTest < MiniTest::Unit::TestCase
  include Directives

  def make_fakefile(lines)
    FakeFile.new(lines.gsub(/^ */, ''))
  end

  def add_conversion_expectation(steps, output, input)
    @line_numbers += steps.map {|step| @current_line + step}
    @current_line = @line_numbers.last
    @total_output += output
    @total_input << input.chomp
  end

  def test_multiline
    @current_line = 0
    @total_output = []
    @total_input = []
    @line_numbers = []
    method_syms = self.methods.select {|symbol| /^command_/ =~ symbol}
    sample_syms = method_syms.sample(7)
    methods = sample_syms.map {|sym| method(sym) }
    methods.each(&:call)
    assert_multiline(@line_numbers, @total_output, @total_input.join("\n"))
  end

  def assert_multiline(steps, instruction_array, string)
    incrementer = steps.to_enum
    fakefile = make_fakefile(string)
    output = process_file(fakefile)
    expected = instruction_array.map {|opcode|
      {:location => {:file => fakefile.path, :linenumber => incrementer.next}, :opcode => opcode}
    }
    assert_equal expected, output
  end

end

class WarningDuringModeTests < MiniTest::Unit::TestCase
  def make_fakefile(lines)
    FakeFile.new(lines.gsub(/^ */, ''))
  end

  def random_name
    (('a'..'z').to_a + [' '] * 4).sample(7).join('').strip.capitalize
  end

  def assert_multiline(steps, instruction_array, string)
    incrementer = steps.to_enum
    fakefile = make_fakefile(string)
    output = process_file(fakefile)
    expected = instruction_array.map {|opcode|
      {:location => {:file => fakefile.path, :linenumber => incrementer.next}, :opcode => opcode}
    }
    assert_equal expected, output
  end

  def add_current_line(expected_steps_for_new_output)
    expected_steps_for_new_output.map {|step| @current_line + step}
  end

  def add_conversion_expectation(steps, output, input, real_line = nil)
    expected_new_line_numbers = (real_line ? steps  : [1,1,2] )
    expected_new_line_content = (real_line ? output : warning_expectation(input) )
    @line_numbers += add_current_line(expected_new_line_numbers)
    @current_line = @line_numbers.last
    @total_input << input.chomp
    @total_output += expected_new_line_content
  end

end

class WarningDuringINModeTest < WarningDuringModeTests
  include Directives

  def line_in
    add_conversion_expectation [1], [[:NOP]], "IN \"#{@room_name}\"", :real_line
  end

  def line_endin
    add_conversion_expectation [1], [[:NOP]], 'ENDIN', :real_line
  end

  def warning_expectation(input)
    [
      [:WARNING, "Directive matched inside \"IN\" state: '#{input}'"],
      [:BUFFER_ROOM, "\"#{@room_name}\"", "\n#{input}"]
    ]
  end

  def test_warnings_for_in
    method_syms = self.methods.select {|symbol| /^command_/ =~ symbol}
    method_syms -= [:command_on, :command_in]
    method_syms -= [:command_comment_line]
    method_syms -= [:command_in_with_comment]
    methods = method_syms.map {|sym| method(sym)}
    methods.each do |method|
      @current_line = 0
      @total_output = []
      @total_input = []
      @line_numbers = []
      @room_name = random_name
      line_in
      method.call()
      line_endin
      assert_multiline(@line_numbers, @total_output, @total_input.join("\n"))
    end
  end

end

class WarningDuringONModeTest < WarningDuringModeTests
  include Directives

  def line_on
    add_conversion_expectation [1], [[:NOP]], "ON \"#{@exit_name}\" FROM \"#{@room_name}\"", :real_line
  end

  def line_endon
    add_conversion_expectation [1], [[:NOP]], 'ENDON', :real_line
  end

  def warning_expectation(input)
    [
      [:WARNING, "Directive matched inside \"ON\" state: '#{input}'"],
      [:BUFFER_EXIT, "\"#{@room_name}\"", "\"#{@exit_name}\"", "\n#{input}"]
    ]
  end

  def test_warnings_for_on
    method_syms = self.methods.select {|symbol| /^command_/ =~ symbol}
    method_syms -= [:command_on, :command_in]
    method_syms -= [:command_comment_line]
    method_syms -= [:command_in_with_comment]
    methods = method_syms.map {|sym| method(sym)}
    methods.each do |method|
      @current_line = 0
      @total_output = []
      @total_input = []
      @line_numbers = []
      @room_name = random_name
      @exit_name = random_name
      line_on
      method.call()
      line_endon
      assert_multiline(@line_numbers, @total_output, @total_input.join("\n"))
    end
  end

end
