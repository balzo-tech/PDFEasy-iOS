//
//  SignedContainerUtilityTests.swift
//  PdfExpertTests
//
//  The envelopes are built here rather than checked in as fixtures: a real `.p7m`
//  carries a real person's certificate, and the shapes that matter (indefinite
//  lengths, split payloads, nesting) are exactly the ones a handful of sample files
//  would fail to cover. The ASN.1 is assembled by hand so each test states which
//  encoding it is about.
//

import XCTest
import UniformTypeIdentifiers
@testable import PdfExpert

final class SignedContainerUtilityTests: XCTestCase {

    // MARK: - Content extraction

    func testExtractsPayloadFromDefiniteLengthEnvelope() throws {
        let payload = Data("%PDF-1.4 hello".utf8)
        let container = CMSBuilder.signedData(payload: payload)

        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "contratto.pdf.p7m")

        XCTAssertEqual(content.data, payload)
        XCTAssertEqual(content.filename, "contratto.pdf")
        XCTAssertEqual(content.contentType, .pdf)
        XCTAssertEqual(content.signatureCount, 1)
    }

    /// The encoding every streaming signer emits, and the one a strict DER reader
    /// silently fails on.
    func testExtractsPayloadFromIndefiniteLengthEnvelope() throws {
        let payload = Data("%PDF-1.4 streamed".utf8)
        let container = CMSBuilder.signedData(payload: payload, indefiniteLengths: true)

        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "fattura.pdf.p7m")

        XCTAssertEqual(content.data, payload)
        XCTAssertEqual(content.filename, "fattura.pdf")
    }

    /// A constructed OCTET STRING: the payload arrives in pieces and has to be joined
    /// back in order.
    func testJoinsPayloadSplitAcrossOctetStringChunks() throws {
        let chunks = [Data("%PDF-1.4 ".utf8), Data("second ".utf8), Data("third".utf8)]
        let container = CMSBuilder.signedData(payloadChunks: chunks)

        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "doc.pdf.p7m")

        XCTAssertEqual(content.data, chunks.reduce(Data(), +))
    }

    /// Counter-signed documents are wrapped twice; the user wants the document, not
    /// the middle envelope.
    func testFollowsNestedEnvelopesToTheDocument() throws {
        let payload = Data("%PDF-1.4 countersigned".utf8)
        let inner = CMSBuilder.signedData(payload: payload)
        let outer = CMSBuilder.signedData(payload: inner)

        let content = try SignedContainerUtility.extractContent(from: outer,
                                                                filename: "atto.pdf.p7m.p7m")

        XCTAssertEqual(content.data, payload)
        XCTAssertEqual(content.filename, "atto.pdf")
        XCTAssertEqual(content.signatureCount, 2)
    }

    func testAcceptsBase64ArmouredContainer() throws {
        let payload = Data("%PDF-1.4 armoured".utf8)
        let der = CMSBuilder.signedData(payload: payload)
        let pem = "-----BEGIN PKCS7-----\n"
            + der.base64EncodedString(options: .lineLength64Characters)
            + "\n-----END PKCS7-----\n"

        let content = try SignedContainerUtility.extractContent(from: Data(pem.utf8),
                                                                filename: "pec.pdf.p7m")

        XCTAssertEqual(content.data, payload)
    }

    // MARK: - Payload typing

    func testSniffsContentTypeFromPayloadBytesNotFilename() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let container = CMSBuilder.signedData(payload: png)

        // The name says PDF; the bytes say PNG, and the bytes decide.
        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "scansione.pdf.p7m")

        XCTAssertEqual(content.contentType, .png)
    }

    func testKeepsContainerNameWhenNoInnerExtensionIsPresent() throws {
        let container = CMSBuilder.signedData(payload: Data("%PDF-1.4 x".utf8))

        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "contratto.p7m")

        XCTAssertEqual(content.filename, "contratto")
        // The extension is gone from the name, so the sniffed type is what routes it.
        XCTAssertEqual(content.contentType, .pdf)
    }

    // MARK: - Refusals

    func testRejectsFileThatIsNotAnEnvelope() {
        let notAContainer = Data("%PDF-1.4 a plain pdf".utf8)

        XCTAssertFalse(SignedContainerUtility.isSignedContainer(data: notAContainer))
        XCTAssertThrowsError(try SignedContainerUtility.extractContent(from: notAContainer,
                                                                      filename: "a.pdf.p7m")) {
            XCTAssertEqual($0 as? SignedContainerError, .notASignedContainer)
        }
    }

    /// A detached signature is a `.p7s` next to the document: nothing to open, and
    /// the user needs to be told that rather than "damaged".
    func testReportsDetachedSignatureSeparately() {
        let container = CMSBuilder.signedData(payload: nil)

        XCTAssertThrowsError(try SignedContainerUtility.extractContent(from: container,
                                                                      filename: "firma.p7s")) {
            XCTAssertEqual($0 as? SignedContainerError, .detachedSignature)
        }
    }

    /// A truncated download must stop at the end of the buffer, not read past it.
    func testRejectsTruncatedContainerWithoutCrashing() {
        let full = CMSBuilder.signedData(payload: Data("%PDF-1.4 truncated payload".utf8))
        let truncated = full.prefix(full.count / 2)

        XCTAssertThrowsError(try SignedContainerUtility.extractContent(from: Data(truncated),
                                                                      filename: "mezzo.pdf.p7m"))
    }

    func testRejectsEnvelopeNestedPastTheLimit() throws {
        var container = CMSBuilder.signedData(payload: Data("%PDF-1.4 deep".utf8))
        for _ in 0..<10 {
            container = CMSBuilder.signedData(payload: container)
        }

        XCTAssertThrowsError(try SignedContainerUtility.extractContent(from: container,
                                                                      filename: "russian.pdf.p7m")) {
            XCTAssertEqual($0 as? SignedContainerError, .tooDeeplyNested)
        }
    }

    // MARK: - Recognition

    func testRecognisesContainerExtensions() {
        for name in ["a.p7m", "a.P7M", "a.pdf.p7m", "a.p7s", "a.m7m"] {
            XCTAssertTrue(SignedContainerUtility.isSignedContainer(url: URL(fileURLWithPath: name)), name)
        }
        for name in ["a.pdf", "a.docx", "a.p7"] {
            XCTAssertFalse(SignedContainerUtility.isSignedContainer(url: URL(fileURLWithPath: name)), name)
        }
    }

    // MARK: - Declared signers

    /// A container with no certificates names nobody — and must say so rather than
    /// fall back on the CA chain or on a guess. The sheet has its own wording for
    /// this case.
    func testNamesNobodyWhenTheEnvelopeCarriesNoCertificates() throws {
        let container = CMSBuilder.signedData(payload: Data("%PDF-1.4 anon".utf8))

        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "anonimo.pdf.p7m")

        XCTAssertTrue(content.declaredSigners.isEmpty)
        XCTAssertTrue(SignedContainerUtility.declaredSignerNames(in: content).isEmpty)
    }

    // MARK: - A container OpenSSL actually produced

    /// Everything above builds its own ASN.1, which proves the reader walks the
    /// shapes it was told about. This one was signed by OpenSSL against a real
    /// self-signed certificate (`CN=MARIO ROSSI`), so it also covers the parts no
    /// hand-built envelope exercises: a genuine SignerInfo, a genuine X.509, and the
    /// serial matching that tells the person apart from the CA chain.
    ///
    ///     openssl smime -sign -binary -in contratto.pdf -out contratto.pdf.p7m \
    ///         -outform DER -signer cert.pem -inkey key.pem -nodetach
    func testReadsAContainerSignedByOpenSSL() throws {
        let container = try XCTUnwrap(Data(base64Encoded: Self.opensslSignedPdf,
                                           options: .ignoreUnknownCharacters))

        let content = try SignedContainerUtility.extractContent(from: container,
                                                                filename: "contratto.pdf.p7m")

        XCTAssertEqual(content.filename, "contratto.pdf")
        XCTAssertEqual(content.contentType, .pdf)
        XCTAssertTrue(content.data.starts(with: Array("%PDF".utf8)))
        XCTAssertEqual(SignedContainerUtility.declaredSignerNames(in: content), ["MARIO ROSSI"])
    }

    /// `contratto.pdf` signed with a throwaway certificate. Nothing here is secret:
    /// the key was generated for this test and discarded.
    private static let opensslSignedPdf: String =
        "MIIHhwYJKoZIhvcNAQcCoIIHeDCCB3QCAQExDzANBglghkgBZQMEAgEFADCCAaAGCSqGSIb3DQEH" +
        "AaCCAZEEggGNJVBERi0xLjQKMSAwIG9iajw8L1R5cGUvQ2F0YWxvZy9QYWdlcyAyIDAgUj4+ZW5k" +
        "b2JqCjIgMCBvYmo8PC9UeXBlL1BhZ2VzL0tpZHNbMyAwIFJdL0NvdW50IDE+PmVuZG9iagozIDAg" +
        "b2JqPDwvVHlwZS9QYWdlL1BhcmVudCAyIDAgUi9NZWRpYUJveFswIDAgNTk1IDg0Ml0vUmVzb3Vy" +
        "Y2VzPDwvRm9udDw8L0YxIDQgMCBSPj4+Pi9Db250ZW50cyA1IDAgUj4+ZW5kb2JqCjQgMCBvYmo8" +
        "PC9UeXBlL0ZvbnQvU3VidHlwZS9UeXBlMS9CYXNlRm9udC9IZWx2ZXRpY2E+PmVuZG9iago1IDAg" +
        "b2JqPDwvTGVuZ3RoIDc2Pj5zdHJlYW0KQlQgL0YxIDI4IFRmIDcwIDcwMCBUZCAoQ29udHJhdHRv" +
        "IGRpIHByb3ZhIGZpcm1hdG8pIFRqIEVUCmVuZHN0cmVhbQplbmRvYmoKdHJhaWxlcjw8L1Jvb3Qg" +
        "MSAwIFI+PqCCA1MwggNPMIICN6ADAgECAhRGGcIH0uUgSdtpW8aHse9YI8/UPjANBgkqhkiG9w0B" +
        "AQsFADA3MRQwEgYDVQQDDAtNQVJJTyBST1NTSTESMBAGA1UECgwJUHJvdmEgU1JMMQswCQYDVQQG" +
        "EwJJVDAeFw0yNjA4MzAxODU5MDFaFw0yNjA5MjkxODU5MDFaMDcxFDASBgNVBAMMC01BUklPIFJP" +
        "U1NJMRIwEAYDVQQKDAlQcm92YSBTUkwxCzAJBgNVBAYTAklUMIIBIjANBgkqhkiG9w0BAQEFAAOC" +
        "AQ8AMIIBCgKCAQEAs+2SPEn1keeI9GosOGzK7amuSqZqwazvOFWDOr9UW1m5wRYx8X2STQ7sr3KT" +
        "wiDekkHjitd4JjxguIQ2HfFc9Qp2sSNDHux4uWe+bEHqfQ8bb7LpUr2SlZBmajNglSJCt5J54GdX" +
        "GShmYotTRyHaZYnTy8kIMlbPLqwKIwKUJZIm6wNtXIGW4abzqLs+nInzQDJtox4taWB/h+51psF5" +
        "rUrkWMoAK4M+8GMuRqvu0IJRvUZctHYXs+SYYc91YO5j34S9ilyp0rL6eX/Rz0MuquIXzvTrAcTt" +
        "UJ/r6loX9yzrDSCJjnhImcnsUymgpZxza0fc7SSkuBcbuysq0/bjpwIDAQABo1MwUTAdBgNVHQ4E" +
        "FgQURSq9RaaY4YhFy4lQjhTs3sp2+fMwHwYDVR0jBBgwFoAURSq9RaaY4YhFy4lQjhTs3sp2+fMw" +
        "DwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAg1CkPz0RUkh4rjAu8ZwRyFO01fOb" +
        "sduJWapI+NMr9sGAjD7H4gGgdAQiIw+C2hiuOSOu8FY58jayRbSL1PwxN2Dpo2xwMva95Au4cO/B" +
        "8lvw+u4hgLB/d+B+kaG2aaY95HYQ/HCLQvQ5eHQLN2OOgXRUA1FkLPNInkBp+F3Sqv4Jv4Zg/WAr" +
        "idAy/uzlfqNt/ldZn5XRQ/fz7mVrUxHLZ/QSiEXlQi5BI7Gm7wlDpzDP1OPw8VDiQy0qOMYZQiKc" +
        "M8lxSal1qLwlu7ciEwJn6oUnzKBs4sShkdn/p5EoiqYOrfMMirDUAMGDhMzM+dBuOQEGKo4oDo+Y" +
        "RvNyfJL3EzGCAmEwggJdAgEBME8wNzEUMBIGA1UEAwwLTUFSSU8gUk9TU0kxEjAQBgNVBAoMCVBy" +
        "b3ZhIFNSTDELMAkGA1UEBhMCSVQCFEYZwgfS5SBJ22lbxoex71gjz9Q+MA0GCWCGSAFlAwQCAQUA" +
        "oIHkMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2MDgzMDE4NTkw" +
        "MVowLwYJKoZIhvcNAQkEMSIEIM/bHvhFdE8JDVJXiAIqisDq26kg0Y6kyxADVHb3QK9/MHkGCSqG" +
        "SIb3DQEJDzFsMGowCwYJYIZIAWUDBAEqMAsGCWCGSAFlAwQBFjALBglghkgBZQMEAQIwCgYIKoZI" +
        "hvcNAwcwDgYIKoZIhvcNAwICAgCAMA0GCCqGSIb3DQMCAgFAMAcGBSsOAwIHMA0GCCqGSIb3DQMC" +
        "AgEoMA0GCSqGSIb3DQEBAQUABIIBAFcAw/uAY1P77VaJviJwpLkGv7+BN5INfQC98S0UzvkETCWC" +
        "BsJUD3op3KP2E8mbkZi5apz+z7ap7GWeAaIkioLY7Hv8yVcNg4POp5z+Co5eE7o4xuTLtIMHMAEp" +
        "nke56w0BYAOa8yerdJj30Liz4T+9w2hyeWbdNCKO+xa/kvyNbSfk2C2AWXN3j1eo5FUskJ6cMHLA" +
        "edQ5B/f4cwC97124mn0ufntGQ5cpD8il4VrZ1SbAeHhl6J8QUv+AMyFddAZ6nOO8qXrC8Q1tdgzB" +
        "0lZ3mSy1Ca+OKWm6Yetyf8gmU+EdbIyyOtbACMSo8Jzmp1AZ8OXQSJPe1june3vu4gw="

    // MARK: - Unwrapping to disk

    func testUnwrapWritesTheDocumentAndLeavesOtherFilesAlone() throws {
        let payload = Data("%PDF-1.4 on disk".utf8)
        let container = CMSBuilder.signedData(payload: payload)
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf.p7m")
        try container.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let unwrapped = try XCTUnwrap(SignedContainerUtility.unwrap(url: source))
        XCTAssertEqual(try Data(contentsOf: unwrapped.url), payload)
        XCTAssertEqual(unwrapped.url.pathExtension, "pdf")

        // A plain PDF is not a container: nothing to unwrap, nothing written.
        let plain = source.deletingPathExtension()
        try payload.write(to: plain)
        defer { try? FileManager.default.removeItem(at: plain) }
        XCTAssertNil(try SignedContainerUtility.unwrap(url: plain))
    }

    func testTwoContainersWithTheSameInnerNameDoNotCollide() throws {
        let first = CMSBuilder.signedData(payload: Data("%PDF-1.4 first".utf8))
        let second = CMSBuilder.signedData(payload: Data("%PDF-1.4 second".utf8))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let a = folder.appendingPathComponent("uno").appendingPathExtension("pdf.p7m")
        let b = folder.appendingPathComponent("due").appendingPathExtension("pdf.p7m")
        try first.write(to: a)
        try second.write(to: b)

        let unwrappedA = try XCTUnwrap(SignedContainerUtility.unwrap(url: a))
        let unwrappedB = try XCTUnwrap(SignedContainerUtility.unwrap(url: b))

        XCTAssertNotEqual(unwrappedA.url, unwrappedB.url)
        XCTAssertEqual(try Data(contentsOf: unwrappedA.url), Data("%PDF-1.4 first".utf8))
        XCTAssertEqual(try Data(contentsOf: unwrappedB.url), Data("%PDF-1.4 second".utf8))
    }
}

// MARK: - Import wiring

/// Stands in for the three view models, so the step they share — envelope off, sheet
/// up, import resumed — is tested once instead of three times.
private final class SignedContainerImportSpy: SignedContainerImporting {
    var signedDocument: SignedDocumentPresentation?
    var failures: [PdfError] = []
    var resumed: [URL] = []

    func onSignedContainerFailure(_ error: PdfError) { self.failures.append(error) }
    func onSignedDocumentOpen(url: URL) { self.resumed.append(url) }
}

@MainActor
final class SignedContainerImportingTests: XCTestCase {

    private func write(_ data: Data, as name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name)
        try data.write(to: file)
        self.addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return file
    }

    /// An ordinary file goes straight through: no sheet, same URL, import unchanged.
    func testOrdinaryFilePassesThroughUntouched() throws {
        let spy = SignedContainerImportSpy()
        let url = try self.write(Data("%PDF-1.4 plain".utf8), as: "piano.pdf")

        XCTAssertEqual(spy.unwrappingSignedContainer(url), url)
        XCTAssertNil(spy.signedDocument)
        XCTAssertTrue(spy.failures.isEmpty)
    }

    /// A container stops the import and puts its signatures on screen; the document
    /// is opened only when the user says so.
    func testContainerStopsTheImportAndPresentsItsSignatures() throws {
        let spy = SignedContainerImportSpy()
        let payload = Data("%PDF-1.4 signed".utf8)
        let url = try self.write(CMSBuilder.signedData(payload: payload), as: "contratto.pdf.p7m")

        XCTAssertNil(spy.unwrappingSignedContainer(url))
        let presented = try XCTUnwrap(spy.signedDocument)
        XCTAssertEqual(presented.content.filename, "contratto.pdf")
        XCTAssertEqual(try Data(contentsOf: presented.url), payload)
        XCTAssertTrue(spy.failures.isEmpty)
        // Nothing was imported yet: that is the user's next tap.
        XCTAssertTrue(spy.resumed.isEmpty)
    }

    /// A damaged container reports the reason it could not be opened rather than the
    /// generic "not a PDF".
    func testDamagedContainerReportsWhy() throws {
        let spy = SignedContainerImportSpy()
        let url = try self.write(Data("not asn.1 at all".utf8), as: "rotto.pdf.p7m")

        XCTAssertNil(spy.unwrappingSignedContainer(url))
        XCTAssertNil(spy.signedDocument)
        XCTAssertEqual(spy.failures.count, 1)
        // PdfError is not Equatable; the message is what the user sees anyway.
        XCTAssertEqual(spy.failures.first?.errorDescription,
                       SignedContainerError.notASignedContainer.localizedDescription)
    }
}

// MARK: - Envelope builder

/// Assembles the parts of a CMS SignedData the reader has to walk. Only the shape
/// matters here — no key is involved, and nothing produced by this is a signature.
enum CMSBuilder {

    static let signedDataOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02]
    static let dataOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x01]

    /// `payload: nil` builds a detached signature — an envelope with no eContent.
    static func signedData(payload: Data?, indefiniteLengths: Bool = false) -> Data {
        self.signedData(payloadChunks: payload.map { [$0] }, indefiniteLengths: indefiniteLengths)
    }

    /// More than one chunk produces a constructed OCTET STRING.
    static func signedData(payloadChunks: [Data]?, indefiniteLengths: Bool = false) -> Data {
        let wrap: (UInt8, Data) -> Data = indefiniteLengths ? self.indefinite : self.definite

        var encapContent = self.definite(0x06, Data(self.dataOID))
        if let payloadChunks {
            let octets: Data
            if payloadChunks.count == 1 {
                octets = self.definite(0x04, payloadChunks[0])
            } else {
                // 0x24: constructed OCTET STRING.
                octets = wrap(0x24, payloadChunks.map { self.definite(0x04, $0) }.reduce(Data(), +))
            }
            encapContent += wrap(0xA0, octets)
        }

        var signedData = self.definite(0x02, Data([0x01]))          // version
        signedData += self.definite(0x31, Data())                   // digestAlgorithms
        signedData += wrap(0x30, encapContent)                      // encapContentInfo
        signedData += self.definite(0x31, Data())                   // signerInfos

        let contentInfo = self.definite(0x06, Data(self.signedDataOID))
            + wrap(0xA0, wrap(0x30, signedData))
        return wrap(0x30, contentInfo)
    }

    private static func definite(_ tag: UInt8, _ content: Data) -> Data {
        var out = Data([tag])
        let length = content.count
        if length < 0x80 {
            out.append(UInt8(length))
        } else {
            var bytes: [UInt8] = []
            var remaining = length
            while remaining > 0 {
                bytes.insert(UInt8(remaining & 0xFF), at: 0)
                remaining >>= 8
            }
            out.append(0x80 | UInt8(bytes.count))
            out.append(contentsOf: bytes)
        }
        out.append(content)
        return out
    }

    private static func indefinite(_ tag: UInt8, _ content: Data) -> Data {
        Data([tag, 0x80]) + content + Data([0x00, 0x00])
    }
}
