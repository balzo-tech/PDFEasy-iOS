//
//  ObfuscatedSecretTests.swift
//  PdfExpertTests
//
//  Verifies the XOR round-trip used to deobfuscate build-time secrets.
//

import XCTest
@testable import PdfExpert

final class ObfuscatedSecretTests: XCTestCase {

    /// XOR helper mirroring the "Generate Secrets" build phase, used to build
    /// known vectors inside the test.
    private func obfuscate(_ string: String, pad: [UInt8]) -> [UInt8] {
        let bytes = Array(string.utf8)
        precondition(bytes.count == pad.count, "pad must match the secret length")
        return zip(bytes, pad).map { $0 ^ $1 }
    }

    func testKnownVectorRoundTrip() {
        // "PDF" = [0x50, 0x44, 0x46]; XOR with a fixed pad, then confirm decode.
        let pad: [UInt8] = [0xAA, 0x01, 0x7F]
        let bytes: [UInt8] = [0x50 ^ 0xAA, 0x44 ^ 0x01, 0x46 ^ 0x7F]
        let secret = ObfuscatedSecret(pad: pad, bytes: bytes)
        XCTAssertEqual(secret.value, "PDF")
    }

    func testEmptySecretDeobfuscatesToEmptyString() {
        let secret = ObfuscatedSecret(pad: [], bytes: [])
        XCTAssertEqual(secret.value, "")
    }

    func testMismatchedLengthsDeobfuscateToEmptyString() {
        // Defensive: malformed input must not crash and must yield "".
        let secret = ObfuscatedSecret(pad: [0x01, 0x02], bytes: [0x03])
        XCTAssertEqual(secret.value, "")
    }

    func testAsciiSecretRoundTrip() {
        let original = "sk-TEST-0123456789abcdef"
        let pad = (0..<original.utf8.count).map { _ in UInt8.random(in: 0...255) }
        let secret = ObfuscatedSecret(pad: pad, bytes: obfuscate(original, pad: pad))
        XCTAssertEqual(secret.value, original)
    }

    func testUnicodeSecretRoundTrip() {
        let original = "clé-secrète-🔐-Ключ"
        let pad = (0..<original.utf8.count).map { _ in UInt8.random(in: 0...255) }
        let secret = ObfuscatedSecret(pad: pad, bytes: obfuscate(original, pad: pad))
        XCTAssertEqual(secret.value, original)
    }
}
