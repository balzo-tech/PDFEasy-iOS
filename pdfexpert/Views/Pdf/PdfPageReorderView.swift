//
//  PdfPageReorderView.swift
//  PdfExpert
//
//  Reordering pages, as a screen instead of a drag inside the thumbnail strip.
//
//  The strip still reorders by drag, and for two or three pages that is the
//  quickest way. Past that it stops working: the strip scrolls in the same
//  direction the drag moves, so a page cannot travel further than the visible
//  window without a fight. A list with the system's own move handles has no such
//  limit, and it is the one reordering gesture people already know.
//

import SwiftUI

struct PdfPageReorderView: View {

    @ObservedObject var viewModel: PdfEditViewModel

    @State private var pageToDelete: Int? = nil

    var body: some View {
        ToolScreen(title: String(localized: "Reorder pages")) {
            List {
                ForEach(Array(self.viewModel.pdfThumbnails.enumerated()), id: \.offset) { index, thumbnail in
                    HStack(spacing: DS.Spacing.sm) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 58)
                            .clipShape(.rect(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(ColorPalette.separator, lineWidth: 0.5)
                            }
                        Text("Page \(index + 1)")
                            .font(forCategory: .body3)
                            .foregroundStyle(ColorPalette.textPrimary)
                        Spacer()
                    }
                    .listRowBackground(ColorPalette.surface)
                }
                .onMove { source, destination in
                    withAnimation(DS.Motion.smooth) {
                        self.viewModel.movePages(from: source, to: destination)
                    }
                }
                .onDelete { offsets in
                    guard let index = offsets.first else { return }
                    self.pageToDelete = index
                }
            }
            .scrollContentBackground(.hidden)
            .background(ColorPalette.background)
            // Always in edit mode: the screen exists to reorder, so making the
            // user ask for the handles first would be a step for nothing.
            .environment(\.editMode, .constant(.active))
            .confirmationDialog(Text("Delete this page?"),
                                isPresented: Binding(get: { self.pageToDelete != nil },
                                                     set: { if !$0 { self.pageToDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: self.pageToDelete) { index in
                Button("Delete", role: .destructive) {
                    self.pageToDelete = nil
                    withAnimation(DS.Motion.smooth) { self.viewModel.deletePage(at: index) }
                }
                Button("Cancel", role: .cancel) { self.pageToDelete = nil }
            }
        }
    }
}
