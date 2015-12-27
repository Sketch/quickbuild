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

end
