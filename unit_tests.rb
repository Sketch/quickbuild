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

  def test_invalid_command
    bogusness = "ZOP BOB B-DOWOP BEZAM BAM BOOM"
    opcode = [:ERROR, "Unrecognized command: #{bogusness}"]

    fakefile = make_fakefile <<-EOS
      #{bogusness}
EOS

    expected = [
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    ]

    output = process_file(fakefile)

    assert_equal expected, output
  end

  def test_command_room_parent_reset
    opcode = [:ROOM_PARENT, nil, nil]

    fakefile = make_fakefile <<-EOS
      ROOM PARENT:
EOS

    expected = [
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    ]

    output = process_file(fakefile)

    assert_equal expected, output
  end

  def test_command_room_parent_raw
    opcode = [:ROOM_PARENT, '#4', :raw]

    fakefile = make_fakefile <<-EOS
      ROOM PARENT: #4
EOS

    expected = [
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    ]

    output = process_file(fakefile)

    assert_equal expected, output
  end

  def test_command_room_parent_id
    opcode = [:ROOM_PARENT, '"Orchard"', :id]

    fakefile = make_fakefile <<-EOS
      ROOM PARENT: "Orchard"
EOS

    expected = [
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    ]

    output = process_file(fakefile)

    assert_equal expected, output
  end

  def test_command_reverse
    opcode = [:REVERSE, '"Ana"', '"Kata"']

    fakefile = make_fakefile <<-EOS
      REVERSE "Ana" "Kata"
EOS

    expected = [
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode}
    ]

    output = process_file(fakefile)

    assert_equal expected, output
  end

  def test_command_on
    opcode = [:BUFFER_ROOM, '"Golden Land"', "\n@describe here=A beautiful place."]

    fakefile = make_fakefile <<-EOS
      IN "Golden Land"
      @describe here=A beautiful place.
      ENDIN
EOS

    expected = [
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => [:NOP]},
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => opcode},
      {:location => {:file => fakefile.path, :linenumber => @incrementer.next}, :opcode => [:NOP]}
    ]

    output = process_file(fakefile)

    assert_equal expected, output
  end

end
