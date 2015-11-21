module PennMUSHDBParser

  def self.exitify(txtobj)
    {
    type:        :exit,
    dbref:       txtobj[/^\d+$/],
    name:        txtobj[/^name "(.*)"$/, 1],
    source:      txtobj[/^exits #(\d+)$/, 1],
    destination: txtobj[/^location #(\d+)$/, 1],
    }
  end

  def self.roomify(txtobj)
    {
    type:        :room,
    dbref:       txtobj[/^\d+$/],
    name:        txtobj[/^name "(.*)"$/, 1],
    exit:        txtobj[/^exits #(\d+)$/, 1],
    }
  end

  def self.objectify(txtobj)
    case txtobj
    when /^type 4$/ then exitify(txtobj)
    when /^type 1$/ then roomify(txtobj)
    end
  end

  def self.gridify(memo, obj)
    case obj[:type]
    when :room then memo.merge({
      :roomhash => memo[:roomhash].merge({ obj[:dbref] => obj }),
      :rooms => memo[:rooms].union([obj]),
    })
    when :exit then memo.merge({
      :exits => memo[:exits].union([obj])
    })
    end
  end

  def self.namify_room(room, table)
    {:name        => room[:name]}
  end

  def self.namify_exit(link, table)
    {:name        => link[:name],
     :source      => table[link[:source]][:name],
     :destination => table[link[:destination]][:name],
    }
  end

  def self.parse_file(filename)
    File.
    read(filename).
    partition("\n!0\n")[1..2].
    join('').
    split("\n!").
    select {|txtobj| /^type [14]$/ =~ txtobj }.
    map {|txtobj| objectify(txtobj) }.
    reduce( # Produce a DBREF->Room hash, Rooms set, and Exits set
      {:roomhash => Hash.new([]),
       :rooms => Set.new(),
       :exits => Set.new(),
    }) {|memo, obj| gridify(memo,obj) }.
    slice_before(:nothing).  # The whole hash as one chunk
    map {|hash_inside_array|
      [:bind_variable].reduce(hash_inside_array.to_h) {|grid, _unused|
        {:roomhash => grid[:roomhash],
         :rooms => Set.new(grid[:rooms].map {|r| namify_room(r, grid[:roomhash]) }),
         :exits => Set.new(grid[:exits].map {|e| namify_exit(e, grid[:roomhash]) }),
        }
      }
    }.
    first.
    values_at(:rooms, :exits).zip([:rooms, :exits]).to_h.invert. # Extract :rooms and :exits
    map {|key,room_or_exit_set|
      [key, room_or_exit_set - [{:name => "Room Zero"}, {:name => "Master Room"}]]
    }.
    to_h
  end

end
