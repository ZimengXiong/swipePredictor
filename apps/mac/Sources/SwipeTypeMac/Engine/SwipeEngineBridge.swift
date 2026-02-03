//
//  SwipeEngineBridge.swift
//  SwipeTypeMac
//

import Foundation

struct Prediction: Identifiable, Equatable, Sendable {
    let id: String
    let word: String
    let score: Double
    let freq: Double

    init(word: String, score: Double, freq: Double) {
        self.id = word
        self.word = word
        self.score = score
        self.freq = freq
    }
}

final class SwipeEngineBridge: @unchecked Sendable {
    static let shared = SwipeEngineBridge()

    private let lock = NSLock()
    private(set) var isLoaded = false
    private(set) var loadedWordCount = 0

    private init() {}

    func loadDictionary(path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let result = path.withCString { swipe_engine_load_dictionary($0) }
        isLoaded = result > 0
        loadedWordCount = max(0, Int(result))
        return Int(result)
    }

    func loadBundledDictionary() -> Int {
        if let bundlePath = Bundle.main.path(forResource: "word_freq", ofType: "txt") {
            return loadDictionary(path: bundlePath)
        }
        return -1
    }

    func predict(input: String, limit: Int = 5) -> [Prediction] {
        lock.lock()
        defer { lock.unlock() }

        guard isLoaded else { return [] }
        guard let ptr = input.withCString({ swipe_engine_predict($0, Int32(limit)) }) else { return [] }
        defer { swipe_engine_free_string(ptr) }

        let json = String(cString: ptr)
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return arr.compactMap { d in
            guard let w = d["word"] as? String, let s = d["score"] as? Double, let f = d["freq"] as? Double else { return nil }
            return Prediction(word: w, score: s, freq: f)
        }
    }
}
