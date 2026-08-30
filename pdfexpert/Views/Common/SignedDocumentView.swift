//
//  SignedDocumentView.swift
//  PdfExpert
//
//  What a `.p7m` shows before the document inside it opens: who the envelope says
//  signed, and how many times. It is a step in the import, not an extra screen —
//  the signature is the reason the file is a container in the first place, and
//  hiding it behind a menu would mean opening a signed contract exactly like an
//  unsigned one.
//
//  The wording is deliberate throughout: "declares", "according to this file". The
//  app reads the envelope, it does not verify the signature — see the note in
//  `SignedContainerUtility`. Saying anything stronger here would be a claim the
//  code cannot back.
//

import SwiftUI

struct SignedDocumentView: View {

    let presentation: SignedDocumentPresentation
    let onOpen: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    private var signerNames: [String] {
        SignedContainerUtility.declaredSignerNames(in: self.presentation.content)
    }

    var body: some View {
        ToolScreen(title: String(localized: "Signed document")) {
            ZStack {
                self.contentView
                self.footerView
            }
            .readableColumn()
            .background(ColorPalette.primaryBG)
        }
        .background(ColorPalette.primaryBG)
    }

    private var contentView: some View {
        Form {
            self.documentSection
            self.signersSection
            self.noticeSection
            // Inset matching the footer button height, so the last row stays
            // reachable above it.
            Spacer().frame(height: 80)
                .listRowBackground(ColorPalette.primaryBG)
        }
        .foregroundColor(ColorPalette.primaryText)
        .background(ColorPalette.primaryBG)
        .scrollContentBackground(.hidden)
    }

    private var documentSection: some View {
        Section(header: self.sectionHeader(String(localized: "Document"))) {
            self.infoRow(label: String(localized: "File"),
                         value: self.presentation.content.filename)
            self.infoRow(label: String(localized: "Signatures"),
                         value: "\(self.presentation.content.signatureCount)")
        }
    }

    @ViewBuilder private var signersSection: some View {
        Section(header: self.sectionHeader(String(localized: "Signed by"))) {
            if self.signerNames.isEmpty {
                // Containers that identify their signer by key identifier instead of
                // by issuer and serial: the certificate is in there, but nothing
                // says which one signed, and guessing would put the wrong name on a
                // contract.
                Text("This file does not say who signed it.")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.fourthText)
                    .listRowBackground(ColorPalette.secondaryBG)
            } else {
                ForEach(self.signerNames, id: \.self) { name in
                    HStack(spacing: 12) {
                        Image(systemName: "signature")
                            .foregroundColor(ColorPalette.primaryText)
                        Text(name)
                            .font(forCategory: .body2)
                            .foregroundColor(ColorPalette.primaryText)
                        Spacer()
                    }
                    .listRowBackground(ColorPalette.secondaryBG)
                }
            }
        }
    }

    private var noticeSection: some View {
        Section {
            Text("These are the names this file declares. The app does not check whether the signatures are still valid.")
                .font(forCategory: .caption1)
                .foregroundColor(ColorPalette.fourthText)
                .listRowBackground(ColorPalette.primaryBG)
        }
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Spacer()
            self.getDefaultButton(text: String(localized: "Open document"), onButtonPressed: {
                self.onOpen(self.presentation.url)
            })
            .padding([.top, .leading, .trailing], 16)
            // Less bottom inset than the pushed tool screens use: this one is a
            // sheet, so there is no tab bar underneath to clear.
            .padding(.bottom, 24)
            .background(ColorPalette.primaryBG)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(forCategory: .caption1)
            .foregroundColor(ColorPalette.primaryText)
            .textCase(nil)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.primaryText)
            Spacer()
            Text(value)
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.fourthText)
                .multilineTextAlignment(.trailing)
        }
        .listRowBackground(ColorPalette.secondaryBG)
    }
}

extension View {

    /// Applied by every host that can import an arbitrary file (Home/Tools, editor,
    /// chat selection), the same way `showOfficeImportAlerts` is.
    func showSignedDocumentInfo(_ item: Binding<SignedDocumentPresentation?>,
                                onOpen: @escaping (URL) -> Void) -> some View {
        self.sheet(item: item) { presentation in
            SignedDocumentView(presentation: presentation, onOpen: onOpen)
        }
    }
}
