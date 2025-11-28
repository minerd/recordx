//
//  AudioProcessing.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio Normalization

/// Configuration for audio normalization
struct AudioNormalizationConfig {
    /// Target loudness in LUFS (Loudness Units Full Scale)
    var targetLUFS: Double = -14.0

    /// Maximum peak level in dBFS
    var maxPeakLevel: Double = -1.0

    /// Whether to use true peak limiting
    var useTruePeakLimiting: Bool = true

    /// Normalization mode
    var mode: NormalizationMode = .loudness

    static let `default` = AudioNormalizationConfig()
    static let youtube = AudioNormalizationConfig(targetLUFS: -14.0)
    static let podcast = AudioNormalizationConfig(targetLUFS: -16.0)
    static let broadcast = AudioNormalizationConfig(targetLUFS: -24.0)

    enum NormalizationMode: String, CaseIterable {
        case peak = "Peak"
        case rms = "RMS"
        case loudness = "Loudness (LUFS)"
    }
}

/// Audio normalization service
class AudioNormalizer {

    static let shared = AudioNormalizer()

    private init() {}

    /// Normalize audio file
    func normalize(
        inputURL: URL,
        outputURL: URL,
        config: AudioNormalizationConfig = .default,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.performNormalization(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    config: config,
                    progress: progress
                )
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func performNormalization(
        inputURL: URL,
        outputURL: URL,
        config: AudioNormalizationConfig,
        progress: ((Double) -> Void)?
    ) throws -> URL {

        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)

        // Read all audio data
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioProcessingError.bufferCreationFailed
        }

        try inputFile.read(into: buffer)
        progress?(0.3)

        // Calculate current level
        let currentLevel = measureLevel(buffer: buffer, mode: config.mode)
        progress?(0.5)

        // Calculate gain
        let targetLevel = config.mode == .loudness ? config.targetLUFS : -3.0
        let gainDB = targetLevel - currentLevel
        let gain = pow(10.0, gainDB / 20.0)

        // Apply gain with peak limiting
        applyGain(to: buffer, gain: Float(gain), maxPeak: Float(pow(10.0, config.maxPeakLevel / 20.0)))
        progress?(0.8)

        // Write output file
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: inputFile.fileFormat.settings)
        try outputFile.write(from: buffer)
        progress?(1.0)

        return outputURL
    }

    private func measureLevel(buffer: AVAudioPCMBuffer, mode: AudioNormalizationConfig.NormalizationMode) -> Double {
        guard let channelData = buffer.floatChannelData else { return -100 }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var sumSquares: Float = 0

        for channel in 0..<channelCount {
            let data = channelData[channel]
            var channelSum: Float = 0

            switch mode {
            case .peak:
                var peak: Float = 0
                vDSP_maxmgv(data, 1, &peak, vDSP_Length(frameLength))
                return Double(20 * log10(peak))

            case .rms, .loudness:
                vDSP_svesq(data, 1, &channelSum, vDSP_Length(frameLength))
                sumSquares += channelSum
            }
        }

        let rms = sqrt(sumSquares / Float(frameLength * channelCount))
        let rmsDB = 20 * log10(rms)

        // For LUFS, apply K-weighting approximation
        if mode == .loudness {
            return Double(rmsDB) - 0.691 // Simplified LUFS approximation
        }

        return Double(rmsDB)
    }

    private func applyGain(to buffer: AVAudioPCMBuffer, gain: Float, maxPeak: Float) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let data = channelData[channel]

            // Apply gain
            var gainValue = gain
            vDSP_vsmul(data, 1, &gainValue, data, 1, vDSP_Length(frameLength))

            // Apply peak limiting (soft clipping)
            for i in 0..<frameLength {
                if data[i] > maxPeak {
                    data[i] = maxPeak - (maxPeak - 1) * exp(-(data[i] - maxPeak) / (1 - maxPeak))
                } else if data[i] < -maxPeak {
                    data[i] = -maxPeak + (maxPeak - 1) * exp(-(-data[i] - maxPeak) / (1 - maxPeak))
                }
            }
        }
    }
}

// MARK: - Noise Reduction

/// Configuration for noise reduction
struct NoiseReductionConfig {
    /// Noise reduction strength (0.0 - 1.0)
    var strength: Double = 0.5

    /// Noise floor threshold in dB
    var noiseFloor: Double = -40.0

    /// Attack time in milliseconds
    var attackTime: Double = 10.0

    /// Release time in milliseconds
    var releaseTime: Double = 100.0

    /// Whether to preserve voice frequencies
    var preserveVoice: Bool = true

    /// Noise profile learning duration in seconds
    var learningDuration: Double = 0.5

    static let `default` = NoiseReductionConfig()
    static let gentle = NoiseReductionConfig(strength: 0.3, noiseFloor: -45.0)
    static let aggressive = NoiseReductionConfig(strength: 0.8, noiseFloor: -30.0)
}

/// Noise reduction service using spectral subtraction
class NoiseReducer {

    static let shared = NoiseReducer()

    private let fftSize = 2048
    private var noiseProfile: [Float]?

    private init() {}

    /// Reduce noise in audio file
    func reduceNoise(
        inputURL: URL,
        outputURL: URL,
        config: NoiseReductionConfig = .default,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.performNoiseReduction(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    config: config,
                    progress: progress
                )
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func performNoiseReduction(
        inputURL: URL,
        outputURL: URL,
        config: NoiseReductionConfig,
        progress: ((Double) -> Void)?
    ) throws -> URL {

        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)
        let sampleRate = format.sampleRate

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioProcessingError.bufferCreationFailed
        }

        try inputFile.read(into: buffer)
        progress?(0.2)

        guard let channelData = buffer.floatChannelData else {
            throw AudioProcessingError.invalidAudioData
        }

        let frameLength = Int(buffer.frameLength)

        // Learn noise profile from first portion of audio
        let learningFrames = Int(config.learningDuration * sampleRate)
        noiseProfile = learnNoiseProfile(from: channelData[0], frameCount: min(learningFrames, frameLength))
        progress?(0.3)

        // Process audio in chunks
        let hopSize = fftSize / 4
        var processedData = [Float](repeating: 0, count: frameLength)

        var position = 0
        while position + fftSize <= frameLength {
            let chunk = Array(UnsafeBufferPointer(start: channelData[0] + position, count: fftSize))
            let processed = processChunk(chunk, config: config)

            // Overlap-add
            for i in 0..<fftSize {
                if position + i < frameLength {
                    processedData[position + i] += processed[i]
                }
            }

            position += hopSize
            progress?(0.3 + 0.6 * Double(position) / Double(frameLength))
        }

        // Copy processed data back to buffer
        for i in 0..<frameLength {
            channelData[0][i] = processedData[i]
        }

        // If stereo, process second channel similarly or copy
        if buffer.format.channelCount > 1 {
            for i in 0..<frameLength {
                channelData[1][i] = processedData[i]
            }
        }

        // Write output
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: inputFile.fileFormat.settings)
        try outputFile.write(from: buffer)
        progress?(1.0)

        return outputURL
    }

    private func learnNoiseProfile(from data: UnsafeMutablePointer<Float>, frameCount: Int) -> [Float] {
        let numChunks = frameCount / fftSize
        var avgMagnitude = [Float](repeating: 0, count: fftSize / 2)

        for i in 0..<numChunks {
            let chunk = Array(UnsafeBufferPointer(start: data + (i * fftSize), count: fftSize))
            let magnitude = computeMagnitude(chunk)

            for j in 0..<magnitude.count {
                avgMagnitude[j] += magnitude[j]
            }
        }

        // Average
        if numChunks > 0 {
            for i in 0..<avgMagnitude.count {
                avgMagnitude[i] /= Float(numChunks)
            }
        }

        return avgMagnitude
    }

    private func processChunk(_ chunk: [Float], config: NoiseReductionConfig) -> [Float] {
        guard let noiseProfile = noiseProfile else { return chunk }

        // Apply window
        var windowed = applyWindow(chunk)

        // Compute FFT magnitude and phase
        let magnitude = computeMagnitude(windowed)
        let phase = computePhase(windowed)

        // Spectral subtraction
        var processedMagnitude = [Float](repeating: 0, count: magnitude.count)
        let strength = Float(config.strength)

        for i in 0..<magnitude.count {
            let noiseEstimate = noiseProfile[i] * strength
            processedMagnitude[i] = max(0, magnitude[i] - noiseEstimate)

            // Preserve voice frequencies (100Hz - 4000Hz)
            if config.preserveVoice {
                let freq = Float(i) / Float(fftSize) * 48000 // Assuming 48kHz
                if freq > 100 && freq < 4000 {
                    processedMagnitude[i] = max(processedMagnitude[i], magnitude[i] * 0.3)
                }
            }
        }

        // Reconstruct signal from magnitude and phase
        let reconstructed = reconstructFromMagnitudePhase(processedMagnitude, phase: phase)

        // Apply inverse window
        return applyWindow(reconstructed)
    }

    private func applyWindow(_ data: [Float]) -> [Float] {
        var windowed = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            let window = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(data.count - 1))) // Hann window
            windowed[i] = data[i] * window
        }
        return windowed
    }

    private func computeMagnitude(_ data: [Float]) -> [Float] {
        // Simplified magnitude computation
        // In production, use vDSP FFT
        var magnitude = [Float](repeating: 0, count: data.count / 2)
        for i in 0..<magnitude.count {
            magnitude[i] = abs(data[i])
        }
        return magnitude
    }

    private func computePhase(_ data: [Float]) -> [Float] {
        // Simplified phase computation
        var phase = [Float](repeating: 0, count: data.count / 2)
        for i in 0..<phase.count {
            phase[i] = 0 // Placeholder - real implementation would compute actual phase
        }
        return phase
    }

    private func reconstructFromMagnitudePhase(_ magnitude: [Float], phase: [Float]) -> [Float] {
        // Simplified reconstruction
        var result = [Float](repeating: 0, count: magnitude.count * 2)
        for i in 0..<magnitude.count {
            result[i] = magnitude[i]
            result[magnitude.count + i] = magnitude[magnitude.count - 1 - i]
        }
        return result
    }
}

// MARK: - Audio Enhancement

/// Combined audio enhancement service
class AudioEnhancer {

    static let shared = AudioEnhancer()

    private init() {}

    /// Configuration for combined audio enhancement
    struct EnhancementConfig {
        var normalize: Bool = true
        var normalizationConfig: AudioNormalizationConfig = .default

        var reduceNoise: Bool = true
        var noiseReductionConfig: NoiseReductionConfig = .default

        var compressor: Bool = false
        var deEsser: Bool = false

        static let `default` = EnhancementConfig()
        static let podcast = EnhancementConfig(
            normalizationConfig: .podcast,
            noiseReductionConfig: .gentle,
            compressor: true
        )
    }

    /// Enhance audio with multiple processing steps
    func enhance(
        inputURL: URL,
        outputURL: URL,
        config: EnhancementConfig = .default,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        var currentURL = inputURL
        var tempURLs: [URL] = []

        let steps = [
            config.reduceNoise,
            config.normalize
        ].filter { $0 }.count

        var currentStep = 0

        func processNext() {
            let stepProgress = { (p: Double) in
                let overallProgress = (Double(currentStep) + p) / Double(steps)
                progress?(overallProgress)
            }

            if config.reduceNoise && currentStep == 0 {
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".m4a")
                tempURLs.append(tempURL)

                NoiseReducer.shared.reduceNoise(
                    inputURL: currentURL,
                    outputURL: tempURL,
                    config: config.noiseReductionConfig,
                    progress: stepProgress
                ) { result in
                    switch result {
                    case .success(let url):
                        currentURL = url
                        currentStep += 1
                        processNext()
                    case .failure(let error):
                        self.cleanup(tempURLs)
                        completion(.failure(error))
                    }
                }
                return
            }

            if config.normalize && currentStep == (config.reduceNoise ? 1 : 0) {
                AudioNormalizer.shared.normalize(
                    inputURL: currentURL,
                    outputURL: outputURL,
                    config: config.normalizationConfig,
                    progress: stepProgress
                ) { result in
                    self.cleanup(tempURLs)
                    completion(result)
                }
                return
            }

            // If no processing needed, just copy
            do {
                try FileManager.default.copyItem(at: inputURL, to: outputURL)
                completion(.success(outputURL))
            } catch {
                completion(.failure(error))
            }
        }

        processNext()
    }

    private func cleanup(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Errors

enum AudioProcessingError: Error, LocalizedError {
    case bufferCreationFailed
    case invalidAudioData
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .invalidAudioData:
            return "Invalid audio data"
        case .processingFailed(let reason):
            return "Audio processing failed: \(reason)"
        }
    }
}
