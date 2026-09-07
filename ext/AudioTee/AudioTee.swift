import AudioTeeCore
import CoreAudio
import Foundation

final class AudioTee {
  var includeProcesses: [Int32] = []
  var excludeProcesses: [Int32] = []
  var mute: Bool = false
  var stereo: Bool = false
  var sampleRate: Double?
  var chunkDuration: Double = 0.2

  // Keep the recorder so stop() can stop it.
  private var recorder: AudioRecorder?

  init() {}

  static func main() {
    let parser = SimpleArgumentParser(
      programName: "audiotee",
      abstract: "Capture system audio and stream to stdout",
      discussion: """
        AudioTee captures system audio using Core Audio taps and streams it as structured output.

        Process filtering:
        • include-processes: Only tap specified process IDs (empty = all processes)
        • exclude-processes: Tap all processes except specified ones
        • mute: How to handle processes being tapped

        Examples:
          audiotee                              # Auto format, tap all processes
          audiotee --sample-rate 16000          # Convert to 16kHz mono for ASR
          audiotee --sample-rate 8000           # Convert to 8kHz for telephony
          audiotee --include-processes 1234     # Only tap process 1234
          audiotee --include-processes 1234 5678 9012  # Tap only these processes
          audiotee --exclude-processes 1234 5678       # Tap everything except these
          audiotee --mute                       # Mute processes being tapped
        """
    )

    parser.addArrayOption(
      name: "include-processes",
      help: "Process IDs to include (space-separated, empty = all processes)"
    )

    parser.addArrayOption(
      name: "exclude-processes",
      help: "Process IDs to exclude (space-separated)"
    )

    parser.addFlag(
      name: "mute",
      help: "Mute processes being tapped"
    )

    parser.addFlag(
      name: "stereo",
      help: "Records in stereo"
    )

    parser.addOption(
      name: "sample-rate",
      help: "Target sample rate (8000, 16000, 22050, 24000, 32000, 44100, 48000)"
    )

    parser.addOption(
      name: "chunk-duration",
      help: "Audio chunk duration in seconds",
      defaultValue: "0.2"
    )

    do {
      try parser.parse()

      let includeProcesses = try parser.getArrayValue(
        "include-processes",
        as: Int32.self
      )

      let excludeProcesses = try parser.getArrayValue(
        "exclude-processes",
        as: Int32.self
      )

      let mute = parser.getFlag("mute")
      let stereo = parser.getFlag("stereo")

      let sampleRate = try parser.getOptionalValue(
        "sample-rate",
        as: Double.self
      )

      let chunkDuration = try parser.getValue(
        "chunk-duration",
        as: Double.self
      )

      try AudioTee().run_main(
        includeProcesses: includeProcesses,
        excludeProcesses: excludeProcesses,
        mute: mute,
        stereo: stereo,
        sampleRate: sampleRate,
        chunkDuration: chunkDuration
      )

    } catch ArgumentParserError.helpRequested {
      parser.printHelp()
      exit(0)

    } catch ArgumentParserError.validationFailed(let message) {
      print("Error: \(message)", to: &standardError)
      exit(1)

    } catch let error as ArgumentParserError {
      print("Error: \(error.description)", to: &standardError)
      parser.printHelp()
      exit(1)

    } catch {
      print("Error: \(error)", to: &standardError)
      exit(1)
    }
  }

  func run_main(
    includeProcesses: [Int32],
    excludeProcesses: [Int32],
    mute: Bool,
    stereo: Bool,
    sampleRate: Double?,
    chunkDuration: Double
  ) throws {
    self.includeProcesses = includeProcesses
    self.excludeProcesses = excludeProcesses
    self.mute = mute
    self.stereo = stereo
    self.sampleRate = sampleRate
    self.chunkDuration = chunkDuration

    try validate()
    try run()
  }

  func validate() throws {
    if !includeProcesses.isEmpty && !excludeProcesses.isEmpty {
      throw ArgumentParserError.validationFailed(
        "Cannot specify both --include-processes and --exclude-processes"
      )
    }
  }

  func run() throws {
    setupSignalHandlers()

    AudioTeeLogging.logger.info("Starting AudioTee...")

    guard chunkDuration > 0 && chunkDuration <= 5.0 else {
      AudioTeeLogging.logger.error(
        "Invalid chunk duration",
        context: [
          "chunk_duration": String(chunkDuration),
          "valid_range": "0.0 < duration <= 5.0"
        ]
      )
      throw ExitCode.failure
    }

    let (processes, isExclusive) = convertProcessFlags()

    let tapConfig = TapConfiguration(
      processes: processes,
      muteBehavior: mute ? .muted : .unmuted,
      isExclusive: isExclusive,
      isMono: !stereo
    )

    let audioTapManager = AudioTapManager()

    do {
      try audioTapManager.setupAudioTap(with: tapConfig)
    } catch AudioTeeError.pidTranslationFailed(let failedPIDs) {
      AudioTeeLogging.logger.error(
        "Failed to translate process IDs to audio objects",
        context: [
          "failed_pids": failedPIDs.map(String.init).joined(separator: ", "),
          "suggestion": "Check that the process IDs exist and are running"
        ]
      )
      throw ExitCode.failure
    } catch {
      AudioTeeLogging.logger.error(
        "Failed to setup audio tap",
        context: [
          "error": String(describing: error)
        ]
      )
      throw ExitCode.failure
    }

    guard let deviceID = audioTapManager.getDeviceID() else {
      AudioTeeLogging.logger.error(
        "Failed to get device ID from audio tap manager"
      )
      throw ExitCode.failure
    }

    let outputHandler = BinaryAudioOutputHandler()

    let recorder = try AudioRecorder(
      deviceID: deviceID,
      outputHandler: outputHandler,
      convertToSampleRate: sampleRate,
      chunkDuration: chunkDuration
    )

    // Store the recorder so stop() can access it.
    self.recorder = recorder

    try recorder.startRecording()

    while true {
      let result = CFRunLoopRunInMode(
        CFRunLoopMode.defaultMode,
        0.1,
        false
      )

      if result == CFRunLoopRunResult.stopped ||
         result == CFRunLoopRunResult.finished {
        break
      }
    }

    AudioTeeLogging.logger.info("Shutting down...")

    recorder.stopRecording()

    // Release the recorder after stopping.
    self.recorder = nil
  }

  /// Stops the current recording.
  func stop() {
    AudioTeeLogging.logger.info(
      "Stopping AudioTee..."
    )

    // Stop the run loop so run() can exit.
    CFRunLoopStop(CFRunLoopGetMain())

    // Stop the recorder immediately if one is active.
    recorder?.stopRecording()
  }

  private func setupSignalHandlers() {
    signal(SIGINT) { _ in
      AudioTeeLogging.logger.info(
        "Received SIGINT, initiating graceful shutdown..."
      )

      CFRunLoopStop(CFRunLoopGetMain())
    }

    signal(SIGTERM) { _ in
      AudioTeeLogging.logger.info(
        "Received SIGTERM, initiating graceful shutdown..."
      )

      CFRunLoopStop(CFRunLoopGetMain())
    }
  }

  private func convertProcessFlags() -> ([Int32], Bool) {
    if !includeProcesses.isEmpty {
      return (includeProcesses, false)
    } else if !excludeProcesses.isEmpty {
      return (excludeProcesses, true)
    } else {
      return ([], true)
    }
  }
}

// Helper for stderr output
var standardError = FileHandle.standardError

extension FileHandle: TextOutputStream {
  public func write(_ string: String) {
    let data = Data(string.utf8)
    self.write(data)
  }
}

// Exit code handling
enum ExitCode: Error {
  case failure
}

extension ExitCode {
  var code: Int32 {
    switch self {
    case .failure:
      return 1
    }
  }
}
