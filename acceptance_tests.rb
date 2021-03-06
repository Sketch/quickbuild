#!/usr/bin/env ruby
require 'minitest/autorun'
require 'set'
require 'socket'
require 'tempfile'
require_relative 'pennmush_dbparser'
require_relative 'processors'
require_relative 'acceptance_tests_pennmush'

class AcceptanceTests < MiniTest::Unit::TestCase
  def setup
    @pennmush = PennMUSHController.new()
    @pennmush.install
    @pennmush.shutdown_and_destroy
    @pennmush.startup
    @pennmush.send("connect #1")
    @rooms = Set.new()
    @exits = Set.new()
  end

  def teardown
    @pennmush.shutdown_and_destroy
  end

  def construct_and_send_grid(quickbuild_string)
    quickbuild_string_array = quickbuild_string.split("\n").map(&:strip).delete_if(&:empty?)
    Tempfile.open('quickbuild_tests') do |file|
      file.write(quickbuild_string_array.join("\n"))
      file.rewind
      softcode = process_file_list_into_softcode([file])
      @pennmush.send(softcode.join("\n"))
    end
  end

  def room(name, features = {})
    @rooms.add({:name => name}).merge(features)
  end

  def link(name, source, destination, features = {})
    @exits.add({:name => name, :source => source, :destination => destination}.merge(features))
  end

  def assert_stated_grid
    @pennmush.dump
    db = @pennmush.dbparse
    assert_equal @rooms, db[:rooms]
    assert_equal @exits, db[:exits]
  end

  def test_simple_grid
    room "Red Room"
    room "Blue Room"
    link "Higher", "Red Room", "Blue Room"
    link "Lower", "Blue Room", "Red Room"

    construct_and_send_grid <<-EOS
      "Higher" : "Red Room"  -> "Blue Room"
      "Lower"  : "Blue Room" -> "Red Room"
EOS

    assert_stated_grid
  end

  def test_C_shape
    room "Blue NW"
    room "Green N"
    room "Yellow NE"
    room "Indigo W"
    room "Purple SW"
    room "Red S"
    room "Infrared SE"
    link "e", "Blue NW", "Green N"
    link "e", "Green N", "Yellow NE"
    link "s", "Blue NW", "Indigo W"
    link "s", "Indigo W", "Purple SW"
    link "e", "Purple SW", "Red S"
    link "e", "Red S", "Infrared SE"

    construct_and_send_grid <<-EOS
      "e" : "Blue NW" -> "Green N" -> "Yellow NE"
      "s" : "Blue NW" -> "Indigo W" -> "Purple SW"
      "e" : "Purple SW" -> "Red S" -> "Infrared SE"
EOS

    assert_stated_grid
  end


  def test_idemppotency_1
    room "Blue NW"
    room "Green N"
    room "Yellow NE"
    room "Indigo W"
    room "Purple SW"
    room "Red S"
    room "Infrared SE"
    link "e", "Blue NW", "Green N"
    link "e", "Green N", "Yellow NE"
    link "s", "Blue NW", "Indigo W"
    link "s", "Indigo W", "Purple SW"
    link "e", "Purple SW", "Red S"
    link "e", "Red S", "Infrared SE"

    construct_and_send_grid %q(
      "e" : "Blue NW" -> "Green N" -> "Yellow NE"
      "s" : "Blue NW" -> "Indigo W" -> "Purple SW"
      "e" : "Purple SW" -> "Red S" -> "Infrared SE"
    )

    construct_and_send_grid %q(
      "e" : "Blue NW" -> "Green N" -> "Yellow NE"
      "s" : "Blue NW" -> "Indigo W" -> "Purple SW"
      "e" : "Purple SW" -> "Red S" -> "Infrared SE"
    )

    assert_stated_grid
  end

  def test_reverse_1
    room "Top"
    room "Middle"
    room "Bottom"
    link "u", "Bottom", "Middle"
    link "u", "Middle", "Top"
    link "d",    "Top", "Middle"
    link "d", "Middle", "Bottom"

    construct_and_send_grid %q(
      reverse "u" "d"
      "u" : "Bottom" <-> "Middle" <-> "Top"
    )

    assert_stated_grid
  end

  def test_prebuilt_rooms_1
    room "FirstRoom"
    link "Leap", "Room Zero", "FirstRoom"

    construct_and_send_grid %q(
      PREBUILT "Zero" = #0
      "Leap" : "Zero" -> "FirstRoom"
    )

    assert_stated_grid
  end

  # TODO: Tests to write:
  # Ensure that multiple BUFFER_ROOM ops behave correctly
  # Parent/Zone application with room-ordering properties
  # Tag tests (Maze test)
  # Shop exits feature
  # Error tests:
  #  - Ensure "No entrance to Room X" appears
  #  - Ensure "No exits from Room X" appears
  #  - Prefix all errors with "QB:"
  #  - Add line numbers and room
  # Coalesce warnings to bottom of output
  # Include line number and code to jump to offending room in error messages

end
