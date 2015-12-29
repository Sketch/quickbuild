#!/usr/bin/env ruby
require 'minitest/autorun'
require 'stringio'
require_relative 'processors'

class FakeFile < StringIO
  def path
    'InMemoryTestFile'
  end
end

class UnitTests < MiniTest::Unit::TestCase

  def setup
    @incrementer = (1..100).lazy
  end

  def make_fakefile(lines)
    FakeFile.new(lines.gsub(/^\s+/, ''))
  end

  def assert_output(instruction_array, string)
    fakefile = make_fakefile(string)
    output = process_file(fakefile)
    expected = instruction_array.map {|opcode|
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    }
    assert_equal expected, output
  end

  def test_invalid_command
    bogusness = 'ZOP BOB B-DOWOP BEZAM BAM BOOM'
    assert_output [[:ERROR, "Unrecognized command: #{bogusness}"]], "#{bogusness}"
  end

  def test_command_attr_base
    str = "juniper_town"
    assert_output [[:ATTR_BASE, str]], "ATTR BASE: #{str}"
  end

  def test_command_alias
    str1 = "S"
    str2 = "South"
    assert_output [[:ALIAS, "\"#{str1}\"", str2]], "ALIAS \"#{str1}\" \"#{str2}\""
  end

  def test_command_reverse
    assert_output [[:REVERSE, '"Ana"', '"Kata"']], 'REVERSE "Ana" "Kata"'
  end

  def test_command_room_parent_reset
    assert_output [[:ROOM_PARENT, nil, nil]], 'ROOM PARENT:'
  end

  def test_command_room_parent_raw
    assert_output [[:ROOM_PARENT, '#4', :raw]], 'ROOM PARENT: #4'
  end

  def test_command_room_parent_id
    assert_output [[:ROOM_PARENT, '"Orchard"', :id]], 'ROOM PARENT: "Orchard"'
  end

  def test_command_room_zone_reset
    assert_output [[:ROOM_ZONE, nil, nil]], 'ROOM ZONE:'
  end

  def test_command_room_zone_raw
    assert_output [[:ROOM_ZONE, '#5', :raw]], 'ROOM ZONE: #5'
  end

  def test_command_room_zone_id
    assert_output [[:ROOM_ZONE, '"Lilac"', :id]], 'ROOM ZONE: "Lilac"'
  end

  def test_command_room_flags_reset
    assert_output [[:ROOM_FLAGS, nil]], 'ROOM FLAGS:'
  end

  def test_command_room_flags_set
    str = "TRANSPARENT"
    assert_output [[:ROOM_FLAGS, str]], "ROOM FLAGS: #{str}"
  end


  def test_command_exit_parent_reset
    assert_output [[:EXIT_PARENT, nil, nil]], 'EXIT PARENT:'
  end

  def test_command_exit_parent_raw
    assert_output [[:EXIT_PARENT, '#6', :raw]], 'EXIT PARENT: #6'
  end

  def test_command_exit_parent_id
    assert_output [[:EXIT_PARENT, '"Daisy"', :id]], 'EXIT PARENT: "Daisy"'
  end

  def test_command_exit_zone_reset
    assert_output [[:EXIT_ZONE, nil, nil]], 'EXIT ZONE:'
  end

  def test_command_exit_zone_raw
    assert_output [[:EXIT_ZONE, '#7', :raw]], 'EXIT ZONE: #7'
  end

  def test_command_exit_zone_id
    assert_output [[:EXIT_ZONE, '"Aster"', :id]], 'EXIT ZONE: "Aster"'
  end

  def test_command_exit_flags_reset
    assert_output [[:EXIT_FLAGS, nil]], 'EXIT FLAGS:'
  end

  def test_command_exit_flags_set
    str = "TRANSPARENT"
    assert_output [[:EXIT_FLAGS, str]], "EXIT FLAGS: #{str}"
  end

  def test_command_on
    assert_output [
      [:NOP],
      [:BUFFER_ROOM, '"Golden Land"', "\n@describe here=A beautiful place."],
      [:NOP]
    ], <<-EOS
      IN "Golden Land"
      @describe here=A beautiful place.
      ENDIN
EOS
  end

end
