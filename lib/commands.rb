require 'tmpdir'

module Commands
  YOUTUBE_DL = '/usr/local/bin/youtube-dl'
  YOUTUBE_OPTS = "-x"
  YOUTUBE_DEBUG_OPTS = %w{--write-info-json --write-description}
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
  end
  
  def ffmpeg_cmd(input_file, start, stop, output_file)
    if stop.nil?
      "#{FFMPEG} -i \"#{input_file}\" -vn -c copy -ss #{start} \"#{output_file}\""
    else
      "#{FFMPEG} -i \"#{input_file}\" -vn -c copy -ss #{start} -to #{stop} \"#{output_file}\""
    end
  end
  
end