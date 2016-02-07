Albumizer
=========

Albumizer is a tool which extracts audio from a given URL, and given the right metadata, splits the resulting audio files into a series of (.m4a) tracks.

## Dependencies

The following are expected to be installed on your system before running Albumizer.  Both are fairly straightforward to install on OSX via Homebrew.
* `youtube-dl` provides download of a given media file
* `ffmpeg` provides the audio processing

## Running

The script first downlods basic metadata on the file, verifying that it's both a valid URL and also has access to enough metadata to construct a track listing.  If either of these steps fail, the program will error out.

Note: This program uses some heuristics to get metadata; it's performed fine on a sparse handful of tests but has not been thoroughly checked with many files.

## To Do

* **Track list API integration**.  Metadata is taken from the description field for the original media, which should be checked against a more reliable source.
* **Better validate track listing**.  It's assumed that timestamps accurately represent what's in the original file.
* **More audio export options** to handle more formats (really, just expose more `ffmpeg` functionality)
* **Parallelize calls to ffmpeg**.  It's pretty quick as-is, but hey, speed.