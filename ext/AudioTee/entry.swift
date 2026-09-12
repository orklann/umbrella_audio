import AudioTeeCore
import AudioToolbox
import Foundation

final class SystemAudioPermission {

    private let service = "kTCCServiceAudioCapture" as CFString

    private typealias TCCAccessPreflight =
        @convention(c) (CFString, CFDictionary?) -> Int32

    private typealias TCCAccessRequest =
        @convention(c) (
            CFString,
            CFDictionary?,
            @escaping (Bool) -> Void
        ) -> Void

    private func tccFunction<T>(
        _ name: String,
        _ type: T.Type
    ) -> T? {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC",
            RTLD_NOW
        ) else {
            return nil
        }

        guard let symbol = dlsym(handle, name) else {
            dlclose(handle)
            return nil
        }

        return unsafeBitCast(symbol, to: T.self)
    }

    func isAuthorized() -> Bool {
        guard let preflight = tccFunction(
            "TCCAccessPreflight",
            TCCAccessPreflight.self
        ) else {
            return false
        }

        let status = preflight(service, nil)

        // 0 = authorized
        // 1 = denied
        // 2 = not determined
        return status == 0
    }

    func request(completion: @escaping (Bool) -> Void) {
        guard let request = tccFunction(
            "TCCAccessRequest",
            TCCAccessRequest.self
        ) else {
            completion(false)
            return
        }

        request(service, nil) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
}

@_cdecl("audiotee_permission_request")
public func audiotee_permission_request() {
    let permission = SystemAudioPermission()
    if permission.isAuthorized() {
        print("Authorized!")
        return
    }

    permission.request { granted in
        if granted {
            print("Auido recording permission granted!")
        } else {
            print("Fale to grant Auido recording permission!")
        }
    }
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
