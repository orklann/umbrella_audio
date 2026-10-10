@[Link(ldflags: "-L#{__DIR__}/../ext/dist/release -lAudioTee -framework AudioToolbox -framework CoreAudio -framework AVFoundation -framework Foundation")]
lib Native
  type AVCaptureDevice = Void*
  type NSString = Void*
  fun authorizationStatusForMediaType = "AVCaptureDevice_authorizationStatusForMediaType"(mediaType : NSString) : Int32
  # AVAuthorizationStatus:
  # 0: NotDetermined
  # 1: Restricted
  # 2: Denied
  # 3: Authorized

  fun audiotee_permission_request : Void
  fun audiotee_test : Void
  fun audiotee_main : Void
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

    def has_permission? : Bool
      # AVMediaTypeAudio is "soun" / "audi" -> actually "soun" is for CoreAudio, but AVMediaTypeAudio maps to "soun" or CFString.
      # Alternatively, we can pass the string "soun" or use a standard Cocoa approach.
      # Let's use the runtime to call AVCaptureDevice authorization status safely:

      status = 0 # Default to restricted/denied if bindings fail
      begin
        # In Obj-C: [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]
        # AVMediaTypeAudio constant value is @"soun"
        media_type_audio = LibFoundation.string_with_units("soun".to_unsafe) # or use objective-c runtime

        # Using Crystal's pointer execution or standard Objective-C dispatch:
        status = LibAV.authorizationStatusForMediaType(pointer_to_av_media_type)
      rescue
        # Fallback or handle non-macOS platforms gracefully
      end

      status == 3 # 3 corresponds to AVAuthorizationStatusAuthorized
    end

    def request_permission
      Native.audiotee_permission_request()
    end

    def main
      Native.audiotee_main()
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
