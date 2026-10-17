//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Observation
import Speech
import Synchronization

/// On-device speech to text for voice messages (bipe/docs/audio.md). Audio never leaves the phone.
public nonisolated enum VoiceTranscriber {
    /// The transcript, or `nil` when permission is denied, no on-device model fits, or nothing was said.
    public static func transcribe(fileURL: URL) async -> String? {
        guard await isAuthorized() else { return nil }
        
        let taskBox = Mutex<SFSpeechRecognitionTask?>(nil)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let resumed = Mutex(false)
                let finish: @Sendable (String?) -> Void = { transcript in
                    let shouldResume = resumed.withLock { wasResumed in
                        defer { wasResumed = true }
                        return !wasResumed
                    }
                    if shouldResume {
                        continuation.resume(returning: transcript)
                    }
                }
                // Speech objects are not Sendable: create them inside the lock so they stay in the box's isolation region.
                taskBox.withLock { box in
                    guard let recognizer = onDeviceRecognizer() else {
                        finish(nil)
                        return
                    }
                    let request = SFSpeechURLRecognitionRequest(url: fileURL)
                    // Fail closed: without this flag Apple may send the audio to its servers.
                    request.requiresOnDeviceRecognition = true
                    request.shouldReportPartialResults = false
                    request.addsPunctuation = true
                    
                    box = recognizer.recognitionTask(with: request) { result, error in
                        if error != nil {
                            finish(nil)
                        } else if let result, result.isFinal {
                            let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                            finish(text.isEmpty ? nil : text)
                        }
                    }
                }
            }
        } onCancel: {
            taskBox.withLock { $0?.cancel() }
        }
    }
    
    // MARK: - Private
    
    private static func isAuthorized() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        default:
            return false
        }
    }
    
    /// The first of the user's languages that the phone transcribes offline, then pt-BR.
    /// No language detection: a pt-BR speaker with an English-only phone gets an English transcript.
    private static func onDeviceRecognizer() -> SFSpeechRecognizer? {
        let candidates = Locale.preferredLanguages + ["pt-BR"]
        for identifier in candidates {
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier)),
               recognizer.supportsOnDeviceRecognition,
               recognizer.isAvailable {
                return recognizer
            }
        }
        return nil
    }
}

/// The transcript of a recorded voice message, which the sender can correct before sending.
@MainActor @Observable
public final class VoiceTranscriptDraft {
    public enum State: Sendable, Equatable {
        case transcribing
        case ready
        case unavailable
    }
    
    public var text = ""
    public private(set) var state = State.transcribing
    
    /// The text for the event: only a finished transcript, never an empty string.
    public var caption: String? {
        guard state == .ready else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    @ObservationIgnored private var task: Task<Void, Never>?
    
    public init(fileURL: URL) {
        task = Task { [weak self] in
            let transcript = await VoiceTranscriber.transcribe(fileURL: fileURL)
            guard !Task.isCancelled, let self else { return }
            if let transcript {
                text = transcript
                state = .ready
            } else {
                state = .unavailable
            }
        }
    }
    
    /// A finished transcript without transcription, for previews.
    public init(transcript: String) {
        text = transcript
        state = .ready
    }
    
    public func cancel() {
        task?.cancel()
    }
}

extension VoiceTranscriptDraft: Equatable {
    public nonisolated static func == (lhs: VoiceTranscriptDraft, rhs: VoiceTranscriptDraft) -> Bool {
        lhs === rhs
    }
}
