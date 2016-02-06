#!/usr/bin/env ruby
require 'json'
require 'optparse'
require 'tmpdir'

YOUTUBE_DL = '/usr/local/bin/youtube-dl'
YOUTUBE_OPTS = "-x"
YOUTUBE_DEBUG_OPTS = %w{--write-info-json --write-description}
YOUTUBE_CHECK_OPTS = "-qj"

FFMPEG = '/usr/local/bin/ffmpeg'

class Albumizer
  attr_accessor :options, :url

  def parse_options
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: albumizer.rb [URL]"
  
      opts.on("-v", "--[no-]verbose", "Show output") do |arg|
        options[:verbose] = arg
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
    cmd = "#{YOUTUBE_DL} #{YOUTUBE_CHECK_OPTS} #{self.url}"
    cmd_result = `#{cmd} 2>&1`

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
    cmd = "#{YOUTUBE_DL} #{YOUTUBE_OPTS}"
    
    # Create a template for the output file within a tmpdir
    cmd += " -o \"#{Dir.tmpdir}/%(title)s-%(id)s.%(ext)s\""
    
    # Pass through any debug options & URL
    cmd += " #{YOUTUBE_DEBUG_OPTS}" if verbose?
    cmd += " #{url}"
    
    cmd_result = `#{cmd} 2>&1`

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
      track_file = "#{track[:number]}. #{track[:title]}.m4a"
      
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
  
  private
  def ffmpeg_cmd(input_file, start, stop, output_file)
    if stop.nil?
      "#{FFMPEG} -i \"#{input_file}\" -vn -c copy -ss #{start} \"#{output_file}\""
    else
      "#{FFMPEG} -i \"#{input_file}\" -vn -c copy -ss #{start} -to #{stop} \"#{output_file}\""
    end
  end
end

Albumizer.new.run()
