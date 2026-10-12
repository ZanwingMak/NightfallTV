import XCTest
import AVFoundation
@testable import NightfallTV

final class AudioTests: XCTestCase {
    /// 检查六项真实解码规格、低响度、削波和循环边界，防止仅文件存在却声音不可用。
    func testAudioLevelsStereoAndLoopBoundary() throws {
        XCTAssertEqual(Set(AudioCredit.all.map(\.sound)), Set(SoundKind.allCases.filter(\.isRecording)))
        for credit in AudioCredit.all {
            XCTAssertTrue(credit.sourceURL.hasPrefix("https://"))
            XCTAssertTrue(credit.licenseURL.hasPrefix("https://"))
            XCTAssertFalse(credit.creator.isEmpty)
            XCTAssertFalse(credit.changes.isEmpty)
        }
        for sound in SoundKind.allCases {
            let url = try XCTUnwrap(Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a"))
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.processingFormat.channelCount, 2)
            XCTAssertEqual(file.processingFormat.sampleRate, 44100)
            XCTAssertGreaterThan(Double(file.length) / file.processingFormat.sampleRate, 25)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let channels = try XCTUnwrap(buffer.floatChannelData)
            let count = Int(buffer.frameLength)
            for channel in 0..<2 {
                let values = channels[channel]
                var mean = 0.0, energy = 0.0, deltaEnergy = 0.0, peak = 0.0
                for index in 0..<count {
                    let value = Double(values[index])
                    mean += value; energy += value * value; peak = max(peak, abs(value))
                    if index > 0 { deltaEnergy += pow(value - Double(values[index - 1]), 2) }
                }
                let rms = sqrt(energy / Double(count))
                XCTAssertLessThan(abs(mean / Double(count)), 0.0001, sound.rawValue)
                XCTAssertGreaterThan(rms, 0.01, "\(sound): must not be near-silent")
                XCTAssertLessThan(rms, 0.075, "\(sound): keep sleep-friendly relative levels")
                XCTAssertLessThan(peak, 0.401, "\(sound): leave at least 8 dB of sample headroom")
                let seam = abs(Double(values[0] - values[count - 1]))
                XCTAssertLessThan(seam, max(0.005, 6 * sqrt(deltaEnergy / Double(count - 1))), "\(sound): loop boundary must resemble ordinary adjacent samples")
            }
        }
    }
}
