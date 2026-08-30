//
//  SignedContainerUtility.swift
//  PdfExpert
//
//  Opens CAdES containers — the `.p7m` files that Italy, and every other country on
//  the CAdES profile, attaches to signed documents. iOS cannot open them: the system
//  has no viewer, Mail shows them as an unknown attachment, and every guide on the
//  subject ends with "use a computer". A signed PDF is still a PDF, so all the app
//  needs is to take it out of the envelope.
//
//  Why a hand-written ASN.1 reader: `CMSDecoder` — the framework call that would do
//  this in one line — is macOS-only. There is no iOS equivalent, public or private,
//  so the container is walked directly.
//
//  BER, not just DER: real-world signing tools stream the envelope and emit
//  indefinite-length constructed elements (0x80 header, 00 00 terminator), and split
//  the payload across several OCTET STRINGs. A strict DER reader parses the test
//  files from the QTSPs and then fails on half the mail attachments, so both forms
//  are handled.
//
//  What this does NOT do: verify the signature. Saying "valid" would mean validating
//  the chain against the European Trusted List, checking revocation and the signing
//  time — a different piece of work entirely. This reads *who* the container says
//  signed it, never *whether* the signature holds, and the naming keeps that
//  distinction: `declaredSigners`, not `signers`.
//

import Foundation
import Security
import UniformTypeIdentifiers

enum SignedContainerError: LocalizedError, Equatable {
    /// Not a CMS SignedData envelope (wrong OID, or not ASN.1 at all).
    case notASignedContainer
    /// Structure ended early or a length ran past the buffer.
    case malformed
    /// A detached signature: the envelope carries no payload, the document
    /// travelled separately and there is nothing to show.
    case detachedSignature
    /// Envelopes nested deeper than `maxNestingDepth`.
    case tooDeeplyNested

    var errorDescription: String? {
        switch self {
        case .notASignedContainer:
            return String(localized: "This file is not a digitally signed document.")
        case .malformed:
            return String(localized: "This signed document could not be opened. It may be damaged.")
        // Worth its own wording: nothing is wrong with the file, the document was
        // simply sent separately, and "damaged" would send the user looking for a
        // problem that is not there.
        case .detachedSignature:
            return String(localized: "This file contains only the signature. The signed document was sent separately.")
        case .tooDeeplyNested:
            return String(localized: "This signed document could not be opened. It may be damaged.")
        }
    }
}

/// One certificate the envelope carries. `isSigner` marks the ones a `SignerInfo`
/// actually points at — a container also ships the CA chain, which must not be
/// presented to the user as a person who signed.
struct SignedContainerSigner: Equatable {
    let commonName: String
    let isSigner: Bool
}

/// The document taken out of the envelope, with what the envelope claims about it.
struct SignedContent: Equatable {
    let data: Data
    /// Inner filename, recovered by dropping the container extensions:
    /// `contratto.pdf.p7m` → `contratto.pdf`.
    let filename: String
    /// Sniffed from the payload's own bytes — the outer name lies often enough
    /// (`.p7m` files renamed by mail clients) that the extension is not trusted.
    let contentType: UTType?
    let declaredSigners: [SignedContainerSigner]
    /// How many envelopes had to be opened. Counter-signed documents are commonly
    /// double-wrapped, and the count is worth showing.
    let signatureCount: Int
}

/// A container that has been opened onto disk: where the document now is, and what
/// the envelope said about it.
struct SignedFile {
    let url: URL
    let content: SignedContent
}

class SignedContainerUtility {

    /// Extensions that mean "there is a CMS envelope in here".
    static let containerExtensions: Set<String> = ["p7m", "p7s", "m7m"]

    /// A notary counter-signing a counter-signed contract is three deep; anything
    /// past this is a malformed or hostile file, not a document.
    private static let maxNestingDepth = 8

    private enum OID {
        /// 1.2.840.113549.1.7.2 — id-signedData
        static let signedData: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02]
        /// 1.2.840.113549.1.7.1 — id-data
        static let data: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x01]
    }

    // MARK: - Public API

    /// True if the URL looks like a signed container, by extension alone. Cheap
    /// enough for the import path to ask before reading the file.
    static func isSignedContainer(url: URL) -> Bool {
        self.containerExtensions.contains(url.pathExtension.lowercased())
    }

    /// True if the bytes open as a CMS SignedData envelope, whatever the file is
    /// called. Mail clients rename attachments, so the content decides.
    static func isSignedContainer(data: Data) -> Bool {
        (try? self.parseEnvelope(data: self.normalized(data))) != nil
    }

    /// Unwraps the envelope, following nested signatures down to the real document.
    ///
    /// - Parameters:
    ///   - data: the container's bytes, DER or PEM.
    ///   - filename: the container's filename, used to recover the inner one.
    static func extractContent(from data: Data, filename: String) throws -> SignedContent {
        var payload = self.normalized(data)
        var name = filename
        var signers: [SignedContainerSigner] = []
        var depth = 0

        while true {
            guard depth < self.maxNestingDepth else { throw SignedContainerError.tooDeeplyNested }
            let envelope = try self.parseEnvelope(data: payload)
            guard let content = envelope.content else { throw SignedContainerError.detachedSignature }

            depth += 1
            payload = content
            name = self.strippingContainerExtension(from: name)
            // Outermost first: that is the signature the recipient sees named on the
            // file, and the one to show at the top of the list.
            signers.append(contentsOf: envelope.signers)

            // A `.p7m` inside a `.p7m` is a counter-signature, not the document.
            guard self.isSignedContainer(data: payload) else { break }
        }

        return SignedContent(data: payload,
                             filename: name,
                             contentType: self.sniffContentType(of: payload),
                             declaredSigners: signers,
                             signatureCount: depth)
    }

    /// Takes the document out of the container and writes it next to the original,
    /// so the rest of the import path can carry on with an ordinary file URL.
    ///
    /// Returns nil when the URL is not a container — the caller then does nothing
    /// different, which keeps the check to one line at each import site.
    static func unwrap(url: URL) throws -> SignedFile? {
        guard self.isSignedContainer(url: url) else { return nil }
        let data = try Data(contentsOf: url)
        let content = try self.extractContent(from: data, filename: url.lastPathComponent)

        // Own directory per unwrap: the inner name is the user's, and two documents
        // called `contratto.pdf` must not overwrite each other in the temp folder.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var unwrapped = folder.appendingPathComponent(content.filename)
        // `contratto.p7m` leaves nothing behind to identify the payload by, and the
        // rest of the import path routes on the extension. The sniffed type supplies
        // one; without it the file goes to the converter, which is the same place an
        // unknown document would have gone anyway.
        if unwrapped.pathExtension.isEmpty, let ext = content.contentType?.preferredFilenameExtension {
            unwrapped = unwrapped.appendingPathExtension(ext)
        }
        try content.data.write(to: unwrapped)
        return SignedFile(url: unwrapped, content: content)
    }

    /// "Firmato da MARIO ROSSI" material: the names the envelope points at as
    /// signers, CA certificates left out. Empty when the container identifies its
    /// signers by key identifier rather than by issuer and serial.
    static func declaredSignerNames(in content: SignedContent) -> [String] {
        content.declaredSigners.filter { $0.isSigner }.map { $0.commonName }
    }

    // MARK: - Envelope

    private struct Envelope {
        let content: Data?
        let signers: [SignedContainerSigner]
    }

    /// Walks ContentInfo → SignedData → EncapsulatedContentInfo, and picks up the
    /// certificates on the way past.
    private static func parseEnvelope(data: Data) throws -> Envelope {
        let bytes = [UInt8](data)

        guard let contentInfo = ASN1.element(in: bytes, at: 0), contentInfo.isConstructed else {
            throw SignedContainerError.notASignedContainer
        }
        let top = ASN1.children(in: bytes, of: contentInfo)
        // ContentInfo ::= SEQUENCE { contentType OID, content [0] EXPLICIT ANY }
        guard top.count >= 2,
              top[0].tag == ASN1.Tag.objectIdentifier,
              Array(bytes[top[0].contentStart..<top[0].contentEnd]) == OID.signedData,
              top[1].isContextSpecific, top[1].isConstructed else {
            throw SignedContainerError.notASignedContainer
        }

        guard let signedData = ASN1.children(in: bytes, of: top[1]).first, signedData.isConstructed else {
            throw SignedContainerError.malformed
        }
        // SignedData ::= SEQUENCE { version, digestAlgorithms SET,
        //                           encapContentInfo, certificates [0] IMPLICIT OPTIONAL,
        //                           crls [1] OPTIONAL, signerInfos SET }
        let fields = ASN1.children(in: bytes, of: signedData)
        guard fields.count >= 3 else { throw SignedContainerError.malformed }

        let content = self.encapsulatedContent(in: bytes, of: fields[2])

        // certificates is the [0] constructed field; crls is [1] and is skipped.
        let certificates = fields.dropFirst(3)
            .first { $0.isContextSpecific && $0.tagNumber == 0 }
            .map { ASN1.children(in: bytes, of: $0) } ?? []
        // signerInfos is the trailing SET.
        let signerInfos = fields.last(where: { $0.tag == ASN1.Tag.set })
            .map { ASN1.children(in: bytes, of: $0) } ?? []

        let signerSerials = Set(signerInfos.compactMap { self.serialNumber(inSignerInfo: $0, bytes: bytes) })
        let signers = certificates.compactMap {
            self.signer(fromCertificate: $0, bytes: bytes, signerSerials: signerSerials)
        }
        // The people first, the CA chain after.
        return Envelope(content: content, signers: signers.sorted { $0.isSigner && !$1.isSigner })
    }

    /// EncapsulatedContentInfo ::= SEQUENCE { eContentType OID, eContent [0] EXPLICIT OCTET STRING OPTIONAL }
    ///
    /// Returns nil for a detached signature, where eContent is absent.
    private static func encapsulatedContent(in bytes: [UInt8], of element: ASN1.Element) -> Data? {
        let parts = ASN1.children(in: bytes, of: element)
        guard parts.count >= 2, parts[0].tag == ASN1.Tag.objectIdentifier,
              parts[1].isContextSpecific else { return nil }

        guard let octets = ASN1.children(in: bytes, of: parts[1]).first else { return nil }
        return self.octetStringValue(in: bytes, of: octets)
    }

    /// A constructed OCTET STRING is the payload cut into chunks — every signing tool
    /// that streams its output emits one — and the pieces have to be joined back.
    private static func octetStringValue(in bytes: [UInt8], of element: ASN1.Element) -> Data {
        guard element.isConstructed else {
            return Data(bytes[element.contentStart..<element.contentEnd])
        }
        var joined = Data()
        for chunk in ASN1.children(in: bytes, of: element) {
            joined.append(self.octetStringValue(in: bytes, of: chunk))
        }
        return joined
    }

    // MARK: - Certificates

    /// SignerInfo ::= SEQUENCE { version, sid SignerIdentifier, ... }
    /// SignerIdentifier ::= IssuerAndSerialNumber ::= SEQUENCE { issuer Name, serialNumber INTEGER }
    ///
    /// Nil when the signer is identified by subject key identifier instead — then
    /// nothing gets matched and every certificate is shown as chain.
    private static func serialNumber(inSignerInfo element: ASN1.Element, bytes: [UInt8]) -> Data? {
        let fields = ASN1.children(in: bytes, of: element)
        guard fields.count >= 2, fields[1].tag == ASN1.Tag.sequence else { return nil }
        let issuerAndSerial = ASN1.children(in: bytes, of: fields[1])
        guard let serial = issuerAndSerial.last, serial.tag == ASN1.Tag.integer else { return nil }
        return Data(bytes[serial.contentStart..<serial.contentEnd])
    }

    /// TBSCertificate ::= SEQUENCE { [0] version OPTIONAL, serialNumber INTEGER, ... }
    private static func serialNumber(inCertificate element: ASN1.Element, bytes: [UInt8]) -> Data? {
        guard let tbs = ASN1.children(in: bytes, of: element).first else { return nil }
        let fields = ASN1.children(in: bytes, of: tbs)
        let serial = fields.first { $0.tag == ASN1.Tag.integer }
        guard let serial else { return nil }
        return Data(bytes[serial.contentStart..<serial.contentEnd])
    }

    /// The subject's common name comes from Security.framework rather than from
    /// another hand-rolled X.509 walk: `SecCertificateCopySubjectSummary` already
    /// picks the right RDN and handles the string encodings.
    private static func signer(fromCertificate element: ASN1.Element,
                               bytes: [UInt8],
                               signerSerials: Set<Data>) -> SignedContainerSigner? {
        guard element.tag == ASN1.Tag.sequence else { return nil }
        let der = Data(bytes[element.start..<element.end])
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData),
              let summary = SecCertificateCopySubjectSummary(certificate) as String?,
              !summary.isEmpty else { return nil }

        let serial = self.serialNumber(inCertificate: element, bytes: bytes)
        let isSigner = serial.map { signerSerials.contains($0) } ?? false
        return SignedContainerSigner(commonName: summary, isSigner: isSigner)
    }

    // MARK: - Payload

    /// `contratto.pdf.p7m` → `contratto.pdf`. A container whose name carries no inner
    /// extension keeps its own name; the type is sniffed from the bytes anyway.
    private static func strippingContainerExtension(from filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        guard self.containerExtensions.contains(url.pathExtension.lowercased()) else { return filename }
        let stripped = url.deletingPathExtension().lastPathComponent
        return stripped.isEmpty ? filename : stripped
    }

    /// Magic bytes only. The payload has no declared type inside the envelope, and
    /// the outer filename is not evidence.
    private static func sniffContentType(of data: Data) -> UTType? {
        let prefixes: [([UInt8], UTType)] = [
            (Array("%PDF".utf8), .pdf),
            ([0xFF, 0xD8, 0xFF], .jpeg),
            ([0x89, 0x50, 0x4E, 0x47], .png),
            ([0x50, 0x4B, 0x03, 0x04], .zip),      // also .docx/.xlsx/.pptx
            (Array("<?xml".utf8), .xml)
        ]
        let head = [UInt8](data.prefix(8))
        for (magic, type) in prefixes where head.starts(with: magic) {
            return type
        }
        return nil
    }

    /// PEM in, DER out. Containers arrive base64-armoured often enough — PEC systems
    /// and some web portals emit them that way — that failing on one would look like
    /// a broken file to the user.
    private static func normalized(_ data: Data) -> Data {
        // A DER envelope starts with SEQUENCE; anything else is worth a PEM attempt.
        if data.first == ASN1.Tag.sequence { return data }
        guard let text = String(data: data, encoding: .utf8) else { return data }
        let body = text
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") }
            .joined()
            .trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty,
              let decoded = Data(base64Encoded: body, options: .ignoreUnknownCharacters),
              decoded.first == ASN1.Tag.sequence else { return data }
        return decoded
    }
}

// MARK: - Import path

/// Shared by the three import paths that accept arbitrary files (home, editor, chat
/// selection). A `.p7m` is not a format the app converts: it is a wrapper to take
/// off before the usual routing on file type happens, so each caller only asks
/// `unwrappingSignedContainer` first and is otherwise unchanged.
/// A container opened and waiting: the signatures are shown before the document is,
/// which is the whole reason someone taps a `.p7m` rather than a PDF.
struct SignedDocumentPresentation: Identifiable, Equatable {
    let id: UUID = UUID()
    /// The extracted document on disk, ready for the ordinary import path.
    let url: URL
    let content: SignedContent
}

/// Isolation sits on the requirements, not on the protocol: marking the protocol
/// `@MainActor` isolates every conforming class, and these view models are built by
/// Factory from a nonisolated context.
protocol SignedContainerImporting: AnyObject {
    /// Drives the signature sheet. `@Published` on the conforming view model.
    @MainActor var signedDocument: SignedDocumentPresentation? { get set }
    /// Where this import path reports a file it could not read.
    @MainActor func onSignedContainerFailure(_ error: PdfError)
    /// The user chose to open the document inside the container: carry on importing
    /// `url`, which is a plain file and no longer an envelope.
    @MainActor func onSignedDocumentOpen(url: URL)
}

extension SignedContainerImporting {

    /// The URL to carry on with, or nil when the import stops here — either because
    /// the container could not be opened (the failure has been reported) or because
    /// its signatures are now on screen and the import resumes from
    /// `onSignedDocumentOpen` when the user says so.
    @MainActor func unwrappingSignedContainer(_ url: URL) -> URL? {
        guard SignedContainerUtility.isSignedContainer(url: url) else { return url }
        do {
            guard let unwrapped = try SignedContainerUtility.unwrap(url: url) else { return url }
            self.signedDocument = SignedDocumentPresentation(url: unwrapped.url,
                                                             content: unwrapped.content)
            return nil
        } catch let error as SignedContainerError {
            self.onSignedContainerFailure(.underlyingError(errorDescription: error.localizedDescription))
            return nil
        } catch {
            // Unreadable file, no space to write the payload: the generic wording is
            // right here, the container itself was never the problem.
            self.onSignedContainerFailure(.urlToPdfConversionError)
            return nil
        }
    }
}

// MARK: - Minimal ASN.1 reader

/// Just enough BER/DER to walk a CMS envelope: tags, lengths (definite and
/// indefinite) and children. No decoding of values beyond the raw bytes.
enum ASN1 {

    enum Tag {
        static let integer: UInt8 = 0x02
        static let objectIdentifier: UInt8 = 0x06
        static let sequence: UInt8 = 0x30
        static let set: UInt8 = 0x31
    }

    struct Element {
        let tag: UInt8
        /// Offset of the tag byte — the element including its header.
        let start: Int
        let contentStart: Int
        let contentEnd: Int
        /// Where the next sibling begins (past the end-of-contents octets, if any).
        let end: Int

        var isConstructed: Bool { (self.tag & 0x20) != 0 }
        var isContextSpecific: Bool { (self.tag & 0xC0) == 0x80 }
        var tagNumber: UInt8 { self.tag & 0x1F }
    }

    /// Reads one element at `offset`. Nil when the buffer ends early or a length runs
    /// past it — a truncated file must not be read past its end.
    static func element(in bytes: [UInt8], at offset: Int) -> Element? {
        guard offset + 1 < bytes.count else { return nil }
        let tag = bytes[offset]
        // End-of-contents: a terminator, not an element.
        guard tag != 0x00 else { return nil }

        let lengthByte = bytes[offset + 1]
        var contentStart = offset + 2

        if lengthByte == 0x80 {
            // Indefinite length: the content runs until a 00 00 at this level.
            guard let terminator = self.endOfIndefinite(in: bytes, from: contentStart) else { return nil }
            return Element(tag: tag, start: offset, contentStart: contentStart,
                           contentEnd: terminator, end: terminator + 2)
        }

        var length = Int(lengthByte)
        if lengthByte & 0x80 != 0 {
            let count = Int(lengthByte & 0x7F)
            guard count > 0, count <= 8, contentStart + count <= bytes.count else { return nil }
            length = 0
            for index in 0..<count {
                length = (length << 8) | Int(bytes[contentStart + index])
            }
            contentStart += count
        }

        let contentEnd = contentStart + length
        guard length >= 0, contentEnd <= bytes.count else { return nil }
        return Element(tag: tag, start: offset, contentStart: contentStart,
                       contentEnd: contentEnd, end: contentEnd)
    }

    /// Scans siblings from `offset` until the 00 00 that closes an indefinite-length
    /// element, returning its position.
    private static func endOfIndefinite(in bytes: [UInt8], from offset: Int) -> Int? {
        var cursor = offset
        while cursor + 1 < bytes.count {
            if bytes[cursor] == 0x00 && bytes[cursor + 1] == 0x00 { return cursor }
            guard let child = self.element(in: bytes, at: cursor), child.end > cursor else { return nil }
            cursor = child.end
        }
        return nil
    }

    /// The elements directly inside a constructed one.
    static func children(in bytes: [UInt8], of element: Element) -> [Element] {
        guard element.isConstructed else { return [] }
        var result: [Element] = []
        var cursor = element.contentStart
        while cursor < element.contentEnd {
            guard let child = self.element(in: bytes, at: cursor), child.end > cursor else { break }
            result.append(child)
            cursor = child.end
        }
        return result
    }
}
