//
//  DocumentDropDestination.swift
//  PdfExpert
//
//  Dropping a file onto the app from Files, Safari or Mail. On an iPad running
//  two apps side by side this is the gesture people try before they go looking
//  for an import button, so the surfaces that can accept a document say so by
//  lighting up under the drag.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Turns what was dropped into one document.
///
/// A dropped PDF is taken on its own: dropping three contracts and getting a
/// single merged file would be a surprise, and merging already has a tool. A
/// batch of images, on the other hand, becomes one document with a page each —
/// the same thing "Image to PDF" does with a multiple selection.
enum DroppedDocument {

    static let acceptedTypes: [UTType] = [.pdf, .image]

    /// True when there is at least one item the app knows how to open. Checked
    /// before accepting the drop so an unsupported file bounces back to its
    /// source instead of silently disappearing.
    static func canImport(_ providers: [NSItemProvider]) -> Bool {
        providers.contains { provider in
            self.acceptedTypes.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        }
    }

    static func makeDocument(from providers: [NSItemProvider]) async -> Pdf? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            guard let data = await self.loadData(from: provider, type: .pdf),
                  var pdf = Pdf(data: data) else { continue }
            if let name = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                pdf.updateFilename(name.lowercased().hasSuffix(".pdf") ? name : "\(name).pdf")
            }
            return pdf
        }

        let document = PDFDocument()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            guard let data = await self.loadData(from: provider, type: .image),
                  let image = UIImage(data: data)?.fixedOrientation() else { continue }
            PDFUtility.appendImageToPdfDocument(pdfDocument: document, uiImage: image)
        }
        guard document.pageCount > 0 else { return nil }
        return Pdf(pdfDocument: document)
    }

    private static func loadData(from provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

extension View {

    /// Accepts PDFs and images dropped from another app.
    ///
    /// - Parameters:
    ///   - inset: how far inside the view's bounds the highlight sits. A grid
    ///     that already pads its content wants the ring around the padding, not
    ///     around the scroll view's edge.
    ///   - onImport: receives the assembled document on the main actor.
    func documentDropDestination(inset: CGFloat = 0,
                                 onImport: @escaping (Pdf) -> Void) -> some View {
        self.modifier(DocumentDropDestination(inset: inset, onImport: onImport))
    }
}

private struct DocumentDropDestination: ViewModifier {

    let inset: CGFloat
    let onImport: (Pdf) -> Void

    @State private var isTargeted: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if self.isTargeted {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(ColorPalette.accent,
                                      style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .background(ColorPalette.accent.opacity(0.06),
                                    in: .rect(cornerRadius: DS.Radius.card, style: .continuous))
                        .padding(self.inset)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(DS.Motion.quick, value: self.isTargeted)
            .onDrop(of: DroppedDocument.acceptedTypes, isTargeted: self.$isTargeted) { providers in
                guard DroppedDocument.canImport(providers) else { return false }
                Task {
                    guard let pdf = await DroppedDocument.makeDocument(from: providers) else { return }
                    await MainActor.run { self.onImport(pdf) }
                }
                return true
            }
    }
}

/// A saved document leaving the app: the same file the share sheet would hand
/// over, so dragging into Mail and sharing produce identical attachments.
struct PdfFileTransfer: Transferable {

    let pdf: Pdf

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { transfer in
            SentTransferredFile(PDFUtility.processToShare(pdf: transfer.pdf, applyPostProcess: true))
        }
        .suggestedFileName { $0.pdf.filename }
    }
}
