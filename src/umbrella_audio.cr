@[Link(ldflags: "-L#{__DIR__}/../ext/dist/release -lAudioTee -framework AudioToolbox -framework CoreAudio -framework Foundation")]
lib Native
  fun audiotee_test : Void
  fun audiotee_start(
      include_pids : Int32*,
      include_count : LibC::SizeT,
      exclude_pids : Int32*,
      exclude_count : LibC::SizeT,
      mute : Bool,
      stereo : Bool,
      sample_rate : Float64,
      has_sample_rate : Bool,
      chunk_duration : Float64
    ) : Void
end

module UmbrellaAudio
  class UmbrellaAudio
    def initialize

    end

    def start(
      include_pids : Int32*,
      exclude_pids : Int32*,
      mute : Bool,
      stereo : Bool,
      sample_rate : Float64,
      has_sample_rate : Bool,
      chunk_duration : Float64
    )
      Native.audiotee_start(
        include_pids,
        include_pids.size,
        exclude_pids,
        exclude_pids.size,
        mute,                  # mute
        stereo,                # stereo
        sample_rate || 0.0,    # sampleRate value
        has_sample_rate,       # hasSampleRate flag
        chunk_duration         # chunkDuration
      )
    end
  end
end
