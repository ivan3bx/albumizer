#!/usr/bin/env ruby
require 'json'
require 'optparse'
require 'readline'
require './lib/commands'

class Albumizer
  include Commands
  attr_accessor :options, :url
  
  AlbumInfo = Struct.new(:title, :year, :artist, :genre, :num_tracks)
  TrackInfo = Struct.new(:number, :title, :start, :stop)
  
  def parse_options
    options = {:output_dir => "."}
    OptionParser.new do |opts|
      opts.banner = "Usage: albumizer.rb [URL]"
  
      opts.on("-v", "--[no-]verbose", "Show output") do |arg|
        options[:verbose] = arg
      end
      
      opts.on("-o", "--output DIRECTORY", "Output to directory") do |arg|
        options[:output_dir] = arg
      end
      
      opts.on("-n", "--[no-]skip-download", "Show the plan but don't download media") do |arg|
        options[:skip_download] = arg
      end
    
      opts.on_tail
    
    end.parse!
    
    self.options = options
    self.url = ARGV.pop
    raise "Requires a URL" unless self.url
  end
  
  def verbose? 
    self.options[:verbose]
  end
    
  def run()
    parse_options
    
    # Validate output directory
    output_dir = self.options[:output_dir]
    if !Dir.exist?(output_dir)
      puts "Output directory '#{self.options[:output_dir]}'does not exist"
      exit(1)
    end
    
    # Grab file metadata & verify
    metadata        = load_metadata(url)
    (album, tracks) = pre_flight_check(metadata)
    
    # Download and split up files
    file       = download_data(url)
    results    = split(file, album, tracks)
    print_summary(results)
      
  end
  
  def load_metadata(url)
    puts "Loading metadata..."
    cmd_result = check_result(`#{youtube_metadata_cmd(self.url)} 2>&1`)
    metadata = JSON.parse(cmd_result)
    
    return metadata
  end
  
  def pre_flight_check(metadata)
    puts "Checking for track listing..."
    pattern = /^
      (\d+).     # track number and decimal
      .*?        # ...
      \"(.*?)\"  # track name in quotes
      .*?        # ...
      (\d+:\d+)  # start time of this track
    /x
    
    track_list = metadata['description'].split("\n").map(&:strip).select { |e| e =~ pattern }
    
    # Create track entry defaults
    track_info = track_list.map do |line|
      (track_num, title, start) = line.match(pattern).captures
      TrackInfo.new(track_num.rjust(2, '0'), title, start)
    end
    
    # Sets 'stop' timestamp to the start of a track's successor
    track_info.slice(0..-2).each_with_index do |track, index|
      track[:stop] = track_info[index + 1].start
    end
    
    # Create album metadata
    album_info = AlbumInfo.new
    album_info.title = metadata['fulltitle']
    album_info.year  = metadata['fulltitle'].match(/\d{4}/).to_s
    album_info.genre = "Rock"
    album_info.num_tracks = track_info.length
    
    # Prompt for validation
    puts "Parsed description: \"#{album_info.title}\""
    puts " confirm defaults"
    album_info.title  = prompt_for("Album Title", album_info.title)
    album_info.year   = prompt_for("Album Year", album_info.year)
    album_info.artist = prompt_for("Album Artist", album_info.artist)
    album_info.genre  = prompt_for("Album Genre", album_info.genre)
    
    
    if verbose?
      puts "  Album Title: #{album_info.title}, Year: #{album_info.year}"
      puts "  First Track: #{track_info[0]}"
    end
    
    [album_info, track_info]
  end

  def download_data(url)
    puts "Downloading..."
    cmd_result = check_result(`#{youtube_download_cmd(url)} 2>&1`)
    
    # Locate the actual file path within the command output
    file_path = cmd_result.match(/#{Dir.tmpdir}.*\.m4a.*$/).to_s

    if file_path =~ / has already been downloaded/
      file_path.gsub!(' has already been downloaded', '')
    end
    
    if !File.exist?(file_path)
      puts "Unable to find tmp file: '#{file_path}'"
      exit(1)
    end
    
    return file_path
  end
  
  def split(file, album, tracks)
    puts "Splitting out #{tracks.length} tracks..."
    files = []
    tracks.each_with_index do |track, index|
      out_file = File.join(self.options[:output_dir], "#{track.number}. #{track.title}.m4a")
      
      # Run the command
      puts " writing #{out_file}"
      check_result(`#{ffmpeg_cmd(file, album, track, out_file)} 2>&1`)
      
      files << out_file
    end
    files
  end
  
  def print_summary(results)
    puts "Summary: #{results.length} tracks written"
  end
  
  private
  def check_result(result)
    if $? != 0
      puts cmd_result
      exit(1)
    end
    result
  end
  
  def prompt_for(prompt_text, default_value)
    Readline.pre_input_hook = -> do
      Readline.insert_text(default_value) if default_value
      Readline.redisplay

      # Remove the hook right away.
      Readline.pre_input_hook = nil
    end

    Readline.readline("#{prompt_text}: ", false)
  end
end

Albumizer.new.run()
