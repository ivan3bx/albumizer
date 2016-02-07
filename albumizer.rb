#!/usr/bin/env ruby
require 'json'
require 'optparse'
require './lib/commands'

class Albumizer
  include Commands
  attr_accessor :options, :url

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
      p "Output directory '#{self.options[:output_dir]}'does not exist"
      exit(1)
    end
    
    # Grab file metadata & verify
    description = load_metadata(url)
    metadata    = pre_flight_check(description)
    
    # Download and split up files
    file       = download_data(url)
    results    = split(file, metadata)
    print_summary(results)
      
  end
  
  def load_metadata(url)
    p "Loading metadata..."
    cmd_result = `#{youtube_metadata_cmd(self.url)} 2>&1`

    if $? != 0
      p cmd_result
      exit(1)
    end

    metadata = JSON.parse(cmd_result)
    
    if verbose?
      p "Command: #{cmd}\nResponse: #{cmd_result}"
    end
    
    return metadata['description']
  end
  
  def pre_flight_check(description)
    p "Checking for track listing..."
    pattern = /^
      (\d+).     # track number and decimal
      .*?        # ...
      \"(.*?)\"  # track name in quotes
      .*?        # ...
      (\d+:\d+)  # start time of this track
    /x
    
    track_list = description.split("\n").map(&:strip).select { |e| e =~ pattern }
    
    # Create a track entry
    track_list.map do |line|
      (track_num, title, start) = line.match(pattern).captures
      {:number => track_num.rjust(2, '0'), :title => title, :start => start}
    end
  end

  def download_data(url)
    p "Downloading..."
    cmd_result = `#{youtube_download_cmd(url)} 2>&1`

    if $? != 0
      p cmd_result
      exit(1)
    end
    
    # Locate the actual file path within the command output
    file_path = cmd_result.match(/#{Dir.tmpdir}.*$/).to_s

    if file_path =~ / has already been downloaded/
      file_path.gsub!(' has already been downloaded', '')
    end
    
    if !File.exist?(file_path)
      p "Unable to find tmp file: '#{file_path}'"
      exit(1)
    end
    
    return file_path
  end
  
  def split(file, metadata)
    p "Splitting out #{metadata.length} tracks..."
    tracks = []
    metadata.each_with_index do |track, index|
      # start/stop depend on metadata from current/next track
      start = track[:start]
      stop  = index < metadata.length - 1 ? metadata[index+1][:start] : nil
      track_file = File.join(self.options[:output_dir], "#{track[:number]}. #{track[:title]}.m4a")
      
      # Run the command
      cmd_result = `#{ffmpeg_cmd(file, start, stop, track_file)} 2>&1`
      tracks << track_file
    end
    tracks
  end
  
  def print_summary(results)
    p "-- Summary --"
    results.each do |e|
      puts e
    end
  end
  
end

Albumizer.new.run()
