//
//  PdfMarkdownImportView.swift
//  PdfExpert
//
//  Editor for "Markdown to PDF": type or paste the text, or load a .md / .txt file.
//  The conversion result travels through the host's async channel, so the editor
//  opens on success exactly like any other import.
//

import SwiftUI
import UniformTypeIdentifiers

struct PdfMarkdownImportView: ViewModifier {

    @ObservedObject var viewModel: PdfMarkdownImportViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                self.editorView
            }
    }

    private var editorView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: self.$viewModel.text)
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(ColorPalette.secondaryBG)
                    .cornerRadius(8)
                    .overlay(alignment: .topLeading) {
                        // TextEditor has no placeholder of its own.
                        if self.viewModel.text.isEmpty {
                            Text("# Your title\n\nWrite or paste your Markdown here.")
                                .font(forCategory: .body2)
                                .foregroundColor(ColorPalette.thirdText)
                                .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0))
                                .allowsHitTesting(false)
                        }
                    }
                Button(action: { self.viewModel.importFile() }) {
                    Label(String(localized: "Load a Markdown file"), systemImage: "doc.badge.plus")
                        .font(forCategory: .button)
                        .foregroundColor(ColorPalette.buttonGradientStart)
                }
            }
            .padding(16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(String(localized: "Markdown to PDF"))
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.cancel()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Convert")) {
                        self.viewModel.convert()
                    }
                    .disabled(!self.viewModel.canConvert)
                    .foregroundColor(self.viewModel.canConvert ? ColorPalette.primaryText : ColorPalette.thirdText)
                }
            }
            .filePicker(isPresented: self.$viewModel.filePickerShow,
                        fileTypes: K.Misc.ImportFileTypesForMarkdown,
                        onPickedFiles: { self.viewModel.onFilePicked($0.first) })
        }
    }
}

extension View {
    func showMarkdownImportView(viewModel: PdfMarkdownImportViewModel) -> some View {
        self.modifier(PdfMarkdownImportView(viewModel: viewModel))
    }
}
