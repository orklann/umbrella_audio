import AudioTeeCore
import AudioToolbox
import Foundation

@_cdecl("audiotee_permission_request")
public func audiotee_permission_request() {
    let request = AudioRecordingPermission()
    request.request()
}

@_cdecl("audiotee_stop")
public func audiotee_stop(_ handle: UnsafeMutableRawPointer?) {
    guard let handle = handle else {
        return
    }

    let audioTee = Unmanaged<AudioTee>
        .fromOpaque(handle)
        .takeUnretainedValue()

    audioTee.stop()
}

@_cdecl("audiotee_start")
public func AudioTeeStart(
    includePids: UnsafePointer<Int32>?,
    includeCount: Int,
    excludePids: UnsafePointer<Int32>?,
    excludeCount: Int,
    mute: Bool,
    stereo: Bool,
    sampleRate: Double,       // Pass 0.0 or negative to represent 'nil'
    hasSampleRate: Bool,      // Or use a boolean flag for optionality
    chunkDuration: Double
) -> UnsafeMutableRawPointer?  {
    // Reconstruct Swift arrays from C pointers
    let includes: [Int32]
    if let ptr = includePids, includeCount > 0 {
        includes = Array(UnsafeBufferPointer(start: ptr, count: includeCount))
    } else {
        includes = []
    }

    let excludes: [Int32]
    if let ptr = excludePids, excludeCount > 0 {
        excludes = Array(UnsafeBufferPointer(start: ptr, count: excludeCount))
    } else {
        excludes = []
    }

    // Reconstruct Swift optional Double
    let rate: Double? = hasSampleRate ? sampleRate : nil


    let audio = AudioTee()
    do {
        try audio.run_main(
            includeProcesses: includes,
            excludeProcesses: excludes,
            mute: mute,
            stereo: stereo,
            sampleRate: rate,
            chunkDuration: chunkDuration) 
    } catch {

    }

    return Unmanaged.passRetained(audio).toOpaque()
}

@_cdecl("audiotee_test")
public func AudioTeeTest() {
    print("Hello, AudioTee Test")
}
