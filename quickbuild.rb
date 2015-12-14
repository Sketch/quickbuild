#!/usr/bin/env ruby
# Quickbuild - MUSH building tool.
# Original Quickbuild authored by Alan Schwartz, 1999
# Improved, Ruby version by Ryan Dowell, Sketch@M*U*S*H, 2012
# Released under the same license terms as PennMUSH
#
# Usage:
# quickbuild.rb [options] inputfile1 [inputfile2 [...]] > outfile.txt
# Then upload the code in output.txt to a MUSH.
#
# Quickbuild file syntax:
#
# # Comment
# alias "Exit Name" "alias list;separated by;semicolons"
# reverse "Exit Name" "Return Exit Name"
# "Exit Name" : "Source Room Name" -> "Dest Room Name"
# "Exit Name" : "Source Room Name" <-> "Dest Room Name"
# ATTR BASE: <attribute>
# ROOM FLAGS: <flag list>
# ROOM ZONE: <dbref> or "Room Name"
# ROOM PARENT: <dbref> or "Room Name"
# EXIT FLAGS: <flag list>
# EXIT ZONE: <dbref> or "Room Name" (no, that's not an error)
# EXIT PARENT: <dbref> or "Room Name" (no that's not an error)
# DESCRIBE "Room Name" =Description
# IN "Room Name"
# ... MUSH code in mpp format ...
# ENDIN
# ON "Exit Name" FROM "Source Room"
# ... MUSH code in mpp format ...
# ENDON
#

require 'optparse'
require_relative 'processors'


# Program process:
# 1) Process program arguments [Section: Parse options]
# 2) Process input files into opcodes [Section: Input file parser]
# 3) Process opcodes into a graph [Section: Opcodes -> Graph]
# 4) Process graph into building commands [Section: Graph -> Softcode]
#
# Sections are arranged in order of execution, with their helper functions
# and relevant classes at the top and primary function at the bottom.
# [Section: Parse options] is run first, but the other code is kicked
# off by the [Section: Execution] at the end of the file.

# Section: Parse options
options = {}
options[:configfilename] = ['.qbcfg', 'qb.cfg', ENV['HOME'] + '.qbcfg', ENV['HOME'] + 'qb.cfg']
options[:unmanaged] = false
options[:brackets] = true
options[:bidirectional_reverse] = true
options[:nosidefx] = false
options[:debug] = false

OptionParser.new do |opts|
	opts.banner = <<EOT.split(/\n/).join("\n")
Quickbuild v#{VERSION}    - offline MUSH building tool
Released under the same terms as PennMUSH

Quickbuild is a Ruby script that lets you quickly lay out a MUSH area
(a set of rooms connected by exits, optionally zoned and/or parented)
in an easy-to-use format in a text file. It converts this file into
uploadable MUSH code. It's smart about cardinal directions (aliases and
reverse exits), <b>racket style exit-naming, and a few other things. It
can build over and modify areas already built by a Quickbuild script,
enabling easy offline management of a whole MUSH grid.

Usage: quickbuild.rb [options] inputfile1 [inputfile2 [...]] > outfile.txt
EOT
	opts.on("--config-file <filename>", String, "Use <filename> as the configuration file instead of defaults.") do |c|
		options[:configfilename] = c
	end
	opts.on("--no-config-file", "Don't use any configuration file.") do
		options[:configfilename] = nil
	end
	opts.on("-b", "--nobrackets", "Don't detect <B>racket style of exit naming.") do |b|
		options[:brackets] = !b
	end
	opts.on('--noreverse', "REVERSE command is bi-directional by default; make it one-way.") do
		options[:bidirectional_reverse] = false
	end
	opts.on("--unmanaged", "Don't check for existing exits nor ATTR_BASE attributes; Build a new area.") do
		options[:unmanaged] = true
	end
	opts.on('--nosidefx', "Don't generate code containing side-effect functions; code won't work on TinyMUX nor RhostMUSH.") do
		options[:nosidefx] = true
		options[:unmanged] = true
	end
	opts.on("-d", "--debug", "Show debug output") do
		options[:debug] = true
	end
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!
# Program exits here if user did --help

# Section: Execution
if options[:debug] then
	puts "#{options}"
	puts "#{ARGV}"
end


filelist = [options[:configfilename], ARGV].
    flatten.
    select {|f| File.exist?(f) && ! File.directory?(f) }.
    map {|f| File.open(f, 'r') }

puts process_file_list_into_softcode(filelist, options)
