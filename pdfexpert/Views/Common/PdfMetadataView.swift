//
//  PdfMetadataView.swift
//  PdfExpert
//
//  FREE-tier "Document info" screen: read-only document info at the top and the
//  editable standard metadata fields (title, author, subject, creator, keywords)
//  below. Reachable from the editor's "…" menu and from the archive row context
//  menu. Backed by `PdfMetadataViewModel`.
//

import SwiftUI
import Factory

struct PdfMetadataView: View {

    @StateObject var viewModel: PdfMetadataViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ToolScreen(title: String(localized: "Document info")) {
            // The ZStack disables keyboard avoidance for the footer button while
            // keeping it for the metadata text fields (same pattern as the
            // suggested-fields form).
            ZStack {
                self.contentView
                self.footerView
                    .ignoresSafeArea(.keyboard)
            }
            .readableColumn()
            .background(ColorPalette.primaryBG)
        }
        .background(ColorPalette.primaryBG)
        .onAppear(perform: self.viewModel.onAppear)
    }

    private var contentView: some View {
        Form {
            self.infoSection
            self.metadataSection
            // Inset matching the footer button height so the last field stays
            // reachable above it.
            Spacer().frame(height: 90)
                .listRowBackground(ColorPalette.primaryBG)
        }
        .foregroundColor(ColorPalette.primaryText)
        .background(ColorPalette.primaryBG)
        .scrollContentBackground(.hidden)
    }

    private var infoSection: some View {
        Section(header: self.sectionHeader(String(localized: "Info"))) {
            self.infoRow(label: String(localized: "Pages"),
                         value: "\(self.viewModel.pageCount)")
            self.infoRow(label: String(localized: "File size"),
                         value: self.viewModel.fileSizeText)
            self.infoRow(label: String(localized: "PDF version"),
                         value: self.viewModel.pdfVersionText)
            self.infoRow(label: String(localized: "Protected"),
                         value: self.viewModel.isProtected
                            ? String(localized: "Yes")
                            : String(localized: "No"))
            self.infoRow(label: String(localized: "Created"),
                         value: self.viewModel.creationDateText)
            self.infoRow(label: String(localized: "Modified"),
                         value: self.viewModel.modificationDateText)
        }
    }

    private var metadataSection: some View {
        Section(header: self.sectionHeader(String(localized: "Metadata")),
                footer: Text("Separate keywords with commas")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.fourthText)
                    .textCase(nil)) {
            self.metadataField(label: String(localized: "Title"), text: self.$viewModel.title)
            self.metadataField(label: String(localized: "Author"), text: self.$viewModel.author)
            self.metadataField(label: String(localized: "Subject"), text: self.$viewModel.subject)
            self.metadataField(label: String(localized: "Creator"), text: self.$viewModel.creator)
            self.metadataField(label: String(localized: "Keywords"), text: self.$viewModel.keywords)
        }
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Spacer()
            self.getDefaultButton(text: String(localized: "Save"), onButtonPressed: {
                self.viewModel.save()
                self.dismiss()
            })
            .padding([.top, .leading, .trailing], 16)
            .padding(.bottom, 80)
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

    private func metadataField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(forCategory: .caption1)
                .foregroundColor(ColorPalette.fourthText)
            TextField(label, text: text)
                .frame(maxWidth: .infinity)
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.primaryText)
        }
        .listRowBackground(ColorPalette.secondaryBG)
    }
}
