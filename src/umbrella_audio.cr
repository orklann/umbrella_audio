@[Link(ldflags: "-L#{__DIR__}/../ext/dist/release -lAudioTee -framework AudioToolbox -framework CoreAudio -framework Foundation")]
lib Native
  fun audiotee_permission_request(Void) : Void
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
    ) : Void*
  fun audiotee_stop(handle : Void*) : Void
end

module UmbrellaAudio
  class UmbrellaAudio
    @handle : Void*?

    def initialize
      @handle = nil
    end

    def request_permission
      Native.audiotee_permission_request()
    end

    def start(
      include_pids : Array(Int32) = [] of Int32,
      exclude_pids : Array(Int32) = [] of Int32,
      mute : Bool = false,
      stereo : Bool = true,
      sample_rate : Float64? = nil,
      chunk_duration : Float64 = 0.5
    )
      return if @handle
      # Pass .to_unsafe for array pointers, and track if sample_rate is present
      handle = Native.audiotee_start(
        include_pids.to_unsafe,
        include_pids.size,
        exclude_pids.to_unsafe,
        exclude_pids.size,
        mute,
        stereo,
        sample_rate || 0.0,
        !sample_rate.nil?,
        chunk_duration
      )

      @handle = handle
    end

    def stop
      handle = @handle

      return unless handle

      Native.audiotee_stop(handle)

      @handle = nil
    end
  end
end
