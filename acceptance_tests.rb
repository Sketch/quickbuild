#!/usr/bin/env ruby
require 'minitest/autorun'
require 'set'
require 'socket'
require_relative 'pennmush_dbparser'
require_relative 'processors'
require_relative 'acceptance_tests_pennmush'

class AcceptanceTests < MiniTest::Unit::TestCase
  def setup
    @pennmush = PennMUSHController.new()
    @pennmush.install
    @pennmush.startup
    @pennmush.send("connect #1")
    @rooms = Set.new()
    @exits = Set.new()
  end

  def teardown
    @pennmush.shutdown
  end

  def construct_and_send_grid(quickbuild_string)
    quickbuild_string_array = quickbuild_string.split("\n").map(&:strip)
    commandlist = process_file(quickbuild_string_array, SYNTAXP)
    graph = process_opcodes(commandlist, {})
    softcode = process_graph(graph, {})
    @pennmush.send(softcode.join("\n"))
  end

  def room(name, features = {})
    @rooms.add({:name => name}).merge(features)
  end

  def link(name, source, destination, features = {})
    @exits.add({:name => name, :source => source, :destination => destination}.merge(features))
  end

  def test_simple_grid
    room "Red Room"
    room "Blue Room"
    link "Higher", "Red Room", "Blue Room"
    link "Lower", "Blue Room", "Red Room"

    construct_and_send_grid(<<-EOS
      "Higher" : "Red Room"  -> "Blue Room"
      "Lower"  : "Blue Room" -> "Red Room"
EOS
    )

    @pennmush.dump
    db = @pennmush.dbparse
    assert_equal @rooms, db[:rooms]
    assert_equal @exits, db[:exits]
  end

  # TODO: Tests to write:
  # Basic Grid Creation
  # Parent/Zone application with room-ordering properties
  # Tag tests (Maze test)
  # Idempotency tests
  # Shop exits feature
  # Error tests:
  #  - Ensure "No entrance to Room X" appears
  #  - Ensure "No exits from Room X" appears
  #  - Prefix all errors with "QB:"
  #  - Add line numbers and room
  # Coalesce warnings to bottom of output
  # Include line number and code to jump to offending room in error messages

end
