class PennMUSHController

  def initialize(debug = false)
    @debug = debug
  end

  def sysdo(array)
    system(array.join(' && '))
  end

  def outdb
    File.join(%w[test-pennmush game data outdb])
  end

  def indb
    File.join(%w[test-pennmush game data indb])
  end

  def pidfile
    File.join(%w[test-pennmush game netmush.pid])
  end

  public def install
    return if Dir.exist?('test-pennmush')
    sysdo([
      'git clone https://github.com/pennmush/pennmush.git test-pennmush',
      'cd test-pennmush',
      'git checkout 185p7',
      './configure  --without-mysql --without-postgresql --without-sqlite3 --disable-info_slave --disable-ssl_slave',
      'cp options.h.dist options.h',
      'make install',
      'make update',
      'sed -i"" "s/^compress_program.*/compress_program/" ./game/mush.cnf',
      'sed -i"" "s/^uncompress_program.*/uncompress_program/" ./game/mush.cnf',
      'sed -i"" "s/^compress_suffix.*/compress_suffix/" ./game/mush.cnf',
    ])
  end

  def wait_for_dbfile
      debug "Waiting for database file to exist."
      loop until File.exist?(outdb)
      debug "Waiting for end of dump."
      loop until File.readlines(outdb).last.chomp == '***END OF DUMP***'
  end

  public def shutdown_and_destroy
    if File.exist?(pidfile)
      debug "Shutting down running PennMUSH."
      pid = File.read(pidfile).to_i
      Process.kill("INT", pid)
      wait_for_dbfile
    end
    File.delete(outdb) if File.exist?(outdb)
    File.delete(indb) if File.exist?(indb)
    Dir.glob(File.join(%w[test-pennmush game save [^.]*])) {|filename|
      File.delete(filename)
    }
    @pennsocket = nil
  end

  public def dump
    debug "Sending @dump"
    send('@dump')
    wait_for_dbfile
  end

  public def send(string)
    @pennsocket.puts(string)
  end

  def debug(msg)
    puts "--QBTester: #{msg}" if @debug
  end

  def establish_connection
    pennsocket = nil
    until pennsocket
      begin
        pennsocket = TCPSocket.new('localhost', 4201)
        return pennsocket
      rescue Errno::ECONNREFUSED
        retry
      end
    end
  end

  public def startup
    File.delete(outdb) if File.exist?(outdb)
    sysdo([
      'cd ' + File.join(%w[test-pennmush game]),
      './restart' + (@debug ? '' : ' 1>/dev/null 2>/dev/null'),
    ])
    debug "Establishing socket"
    @pennsocket = establish_connection
    debug "Socket established. Waiting for output."
    while line = @pennsocket.gets()
      break if /^----------/ =~ line
    end
    debug "Output received. Connecting character."
    @pennsocket.puts('connect #1')
    @pennsocket.puts('think -- BEGIN TEST SUITE --')
    while line = @pennsocket.gets()
      break if '-- BEGIN TEST SUITE --' == line.chomp
    end
    debug "Connected successfully."
  end

  public def dbparse
    PennMUSHDBParser.parse_file(outdb)
  end

end
