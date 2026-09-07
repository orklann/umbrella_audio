@[Link(ldflags: "-L#{__DIR__}/../ext/dist/release -lAudioTee -framework AudioToolbox -framework CoreAudio -framework Foundation")]
lib Native
  fun audiotee_test : Void
end

module UmbrellaAudio
  class UmbrellaAudio
    def initialize
      Native.audiotee_test()
    end
  end
end
