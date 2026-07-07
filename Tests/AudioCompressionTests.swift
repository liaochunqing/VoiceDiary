import AVFoundation
import XCTest
@testable import VoiceDiary

final class AudioCompressionTests: XCTestCase {
    private let fileManager = FileManager.default

    func testFifteenSecondRecordingIsPlayableAndCompressed() async throws {
        let inputURL = temporaryURL(extension: "caf")
        try makePCMRecording(duration: 15, at: inputURL)

        let data = try await VoiceRecorder.compressedAudioData(from: inputURL)
        let player = try AVAudioPlayer(data: data)

        XCTAssertGreaterThan(data.count, 1_000)
        XCTAssertLessThan(data.count, 1_000_000)
        XCTAssertEqual(player.duration, 15, accuracy: 0.15)
        XCTAssertFalse(fileManager.fileExists(atPath: inputURL.path), "PCM should be deleted after encoding")
    }

    func testInvalidInputIsDeletedInsteadOfBeingStoredAsPCM() async throws {
        let inputURL = temporaryURL(extension: "caf")
        try Data("invalid audio".utf8).write(to: inputURL)

        do {
            _ = try await VoiceRecorder.compressedAudioData(from: inputURL)
            XCTFail("Invalid audio should not encode")
        } catch {
            XCTAssertFalse(fileManager.fileExists(atPath: inputURL.path))
        }
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("AudioCompressionTests-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func makePCMRecording(duration: Int, at url: URL) throws {
        let sampleRate = 48_000.0
        let format = try XCTUnwrap(AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ))
        let framesPerSecond = AVAudioFrameCount(sampleRate)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: framesPerSecond
        ))
        buffer.frameLength = framesPerSecond

        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<Int(framesPerSecond) {
            samples[frame] = sin(Float(frame) * 2 * .pi * 220 / Float(sampleRate)) * 0.2
        }

        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            for _ in 0..<duration { try file.write(from: buffer) }
        }
    }
}
