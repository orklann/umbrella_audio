import AudioTeeCore
import AudioToolbox
import Foundation

public func AudioTeeStart() {
    AudioTee.main()
}

@_cdecl("audiotee_test")
public func AudioTeeTest() {
    print("Hello, AudioTee Test")
}
