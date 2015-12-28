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
    expected = instruction_array.map {|opcode|
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    }
    output = process_file(fakefile)
    assert_equal expected, output
  end

  def test_invalid_command
    bogusness = 'ZOP BOB B-DOWOP BEZAM BAM BOOM'
    assert_output [[:ERROR, "Unrecognized command: #{bogusness}"]], "#{bogusness}"
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

  def test_command_reverse
    assert_output [[:REVERSE, '"Ana"', '"Kata"']], 'REVERSE "Ana" "Kata"'
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
