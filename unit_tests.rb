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
    assert_output [1], [[:NOP]], "# Comment lines begin with a pound."
  end

  def command_attr_base
    str = "juniper_town"
    assert_output [1], [[:ATTR_BASE, str]], "ATTR BASE: #{str}"
  end

  def command_alias
    str1 = "S"
    str2 = "South"
    assert_output [1], [[:ALIAS, "\"#{str1}\"", str2]], "ALIAS \"#{str1}\" \"#{str2}\""
  end

  def command_reverse
    assert_output [1], [[:REVERSE, '"Ana"', '"Kata"']], 'REVERSE "Ana" "Kata"'
  end

  def command_room_parent_reset
    assert_output [1], [[:ROOM_PARENT, nil, nil]], 'ROOM PARENT:'
  end

  def command_room_parent_raw
    assert_output [1], [[:ROOM_PARENT, '#4', :raw]], 'ROOM PARENT: #4'
  end

  def command_room_parent_id
    assert_output [1], [[:ROOM_PARENT, '"Orchard"', :id]], 'ROOM PARENT: "Orchard"'
  end

  def command_room_zone_reset
    assert_output [1], [[:ROOM_ZONE, nil, nil]], 'ROOM ZONE:'
  end

  def command_room_zone_raw
    assert_output [1], [[:ROOM_ZONE, '#5', :raw]], 'ROOM ZONE: #5'
  end

  def command_room_zone_id
    assert_output [1], [[:ROOM_ZONE, '"Lilac"', :id]], 'ROOM ZONE: "Lilac"'
  end

  def command_room_flags_reset
    assert_output [1], [[:ROOM_FLAGS, nil]], 'ROOM FLAGS:'
  end

  def command_room_flags_set
    str = "TRANSPARENT"
    assert_output [1], [[:ROOM_FLAGS, str]], "ROOM FLAGS: #{str}"
  end


  def command_exit_parent_reset
    assert_output [1], [[:EXIT_PARENT, nil, nil]], 'EXIT PARENT:'
  end

  def command_exit_parent_raw
    assert_output [1], [[:EXIT_PARENT, '#6', :raw]], 'EXIT PARENT: #6'
  end

  def command_exit_parent_id
    assert_output [1], [[:EXIT_PARENT, '"Daisy"', :id]], 'EXIT PARENT: "Daisy"'
  end

  def command_exit_zone_reset
    assert_output [1], [[:EXIT_ZONE, nil, nil]], 'EXIT ZONE:'
  end

  def command_exit_zone_raw
    assert_output [1], [[:EXIT_ZONE, '#7', :raw]], 'EXIT ZONE: #7'
  end

  def command_exit_zone_id
    assert_output [1], [[:EXIT_ZONE, '"Aster"', :id]], 'EXIT ZONE: "Aster"'
  end

  def command_exit_flags_reset
    assert_output [1], [[:EXIT_FLAGS, nil]], 'EXIT FLAGS:'
  end

  def command_exit_flags_set
    str = "TRANSPARENT"
    assert_output [1], [[:EXIT_FLAGS, str]], "EXIT FLAGS: #{str}"
  end

  def command_describe
    str1 = "Serene Town"
    str2 = "A peaceful place"
    assert_output [1], [[:BUFFER_ROOM, "\"#{str1}\"", "\n@describe here=\"#{str2}\""]], "DESCRIBE \"#{str1}\"=\"#{str2}\""
  end

  def command_in
    assert_output [1,2,3], [
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
    assert_output [1,2,3], [
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
    assert_output [1,2,3,4], [
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
    assert_output [1,2,3,4], [
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
    assert_output [1,1,1], [
      [:CREATE_ROOM, '"In the Fire"'],
      [:CREATE_ROOM, '"Rising in Smoke"'],
      [:CREATE_EXIT, '"burn"', '"In the Fire"', '"Rising in Smoke"'],
    ], '"burn" : "In the Fire" -> "Rising in Smoke"'
  end

  def command_one_way_construction_extended
    assert_output [1,1,1,1,1], [
      [:CREATE_ROOM, '"In the Fire"'],
      [:CREATE_ROOM, '"Rising in Smoke"'],
      [:CREATE_EXIT, '"burn"', '"In the Fire"', '"Rising in Smoke"'],
      [:CREATE_ROOM, '"Away in The Breeze"'],
      [:CREATE_EXIT, '"burn"', '"Rising in Smoke"', '"Away in The Breeze"']
    ], '"burn" : "In the Fire" -> "Rising in Smoke" -> "Away in The Breeze"'
  end

  def command_two_way_construction
    assert_output [1,1,1,1], [
      [:CREATE_ROOM, '"Green Zone"'],
      [:CREATE_ROOM, '"Blue Zone"'],
      [:CREATE_EXIT, '"shorter"', '"Green Zone"', '"Blue Zone"'],
      [:CREATE_REVERSE_EXIT, '"shorter"', '"Green Zone"', '"Blue Zone"'],
    ], '"shorter" : "Green Zone" <-> "Blue Zone"'
  end

  def command_two_way_construction_extended
    assert_output [1,1,1,1,1,1,1], [
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

  def assert_output(steps, instruction_array, string)
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
    assert_output [1], [[:ERROR, "Unrecognized command: #{bogusness}"]], "#{bogusness}"
  end

  def test_invalid_endin_outside_in_block
    assert_output [1], [[:ERROR, 'ENDIN outside of IN-block.']], 'ENDIN'
  end

  def test_invalid_endon_outside_on_block
    assert_output [1], [[:ERROR, 'ENDON outside of ON-block.']], 'ENDON'
  end

  def test_invalid_endon_inside_in_block
    assert_output [1,2], [
      [:NOP],
      [:WARNING, 'ENDON inside of IN-block.']
    ], <<-EOS
      IN "Desert"
      ENDON
EOS
  end

  def test_invalid_endin_inside_on_block
    assert_output [1,2], [
      [:NOP],
      [:WARNING, 'ENDIN inside of ON-block.']
    ], <<-EOS
      ON "Accelerator" FROM "Tube Station"
      ENDIN
EOS
  end

  def test_blank_line
    assert_output [1], [[:NOP]], "\n"
  end

  def test_whitespace_line
    assert_output [1], [[:NOP]], "\t "
  end

  # TODO:
  #  Add warning for using a REVERSE exit before its definition.
  #  Change invalid block ending directives to :ERROR
end

class MultilineTest < MiniTest::Unit::TestCase
  include Directives

  def make_fakefile(lines)
    FakeFile.new(lines.gsub(/^ */, ''))
  end

  def assert_output(steps, output, input)
    @stepping += steps.map {|step| @current_line + step}
    @current_line = @stepping.last
    @total_output += output
    @total_input << input.chomp
  end

  def test_multiline
    @current_line = 0
    @total_output = []
    @total_input = []
    @stepping = []
    method_syms = self.methods.select {|symbol| /^command_/ =~ symbol}
    sample_syms = method_syms.sample(7)
    methods = sample_syms.map {|sym| method(sym) }
    methods.each(&:call)
    assert_multiline(@stepping, @total_output, @total_input.join("\n"))
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
