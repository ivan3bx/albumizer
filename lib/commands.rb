require 'tmpdir'

module Commands
  YOUTUBE_DL = '/usr/local/bin/youtube-dl'
  YOUTUBE_OPTS = "-x --audio-format=m4a"
  YOUTUBE_DEBUG_OPTS = "--write-info-json --write-description"
  YOUTUBE_CHECK_OPTS = "-qj"

  FFMPEG = '/usr/local/bin/ffmpeg'

  def youtube_metadata_cmd(url)
    "#{YOUTUBE_DL} #{YOUTUBE_CHECK_OPTS} #{url}"
  end
  
  def youtube_download_cmd(url)
    cmd = "#{YOUTUBE_DL} #{YOUTUBE_OPTS}"

    # Create a template for the output file within a tmpdir
    cmd += " -o \"#{Dir.tmpdir}/%(title)s-%(id)s.%(ext)s\""
    
    # Pass through any debug options & URL
    cmd += " #{YOUTUBE_DEBUG_OPTS}" if verbose?
    cmd += " #{url}"
    
    if verbose?
      puts "Download command: #{cmd}"
    end
    
    cmd
  end
  
  def ffmpeg_cmd(input_file, album_info, track_info, output_file)
    tags = { }
    tags["title"]  = track_info.title
    tags["track"]  = "#{track_info.number.to_i}/#{album_info.num_tracks}" if track_info.number
    tags["album"]  = album_info.title if album_info.title
    tags["year"]   = album_info.year if album_info.year
    tags["artist"] = album_info.artist if album_info.artist
    tags["genre"]  = album_info.genre if album_info.genre
    
    metadata = tags.inject([]) { |m,e| m << "-metadata #{e[0]}=\"#{e[1]}\"" }.join(" ")
    
    if track_info.stop.nil?
      cmd = "#{FFMPEG} -y -i \"#{input_file}\" -vn -c copy #{metadata} -ss #{track_info.start} \"#{output_file}\""
    else
      cmd = "#{FFMPEG} -y -i \"#{input_file}\" -vn -c copy #{metadata} -ss #{track_info.start} -to #{track_info.stop} \"#{output_file}\""
    end
    
    if verbose?
      puts " #{cmd}"
    end

    cmd
  end
  
end
