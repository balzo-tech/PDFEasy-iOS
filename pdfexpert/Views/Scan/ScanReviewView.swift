//
//  ScanReviewView.swift
//  PdfExpert
//
//  What was scanned, page by page, with the four things anyone wants to do to a
//  page that came out wrong: re-corner it, re-filter it, turn it, or bin it.
//
//  The pager is the whole screen because the page is the content. The actions
//  sit on glass below it, and the one destructive action asks first — a scan is
//  a photo of something that may not be in front of the user any more.
//

import SwiftUI

struct ScanReviewView: View {

    @ObservedObject var viewModel: DocumentScanViewModel

    @State private var cropShow: Bool = false
    @State private var filterShow: Bool = false
    @State private var organizerShow: Bool = false
    @State private var deleteConfirmationShow: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                self.topBar
                self.pager
                self.pageIndicator
                self.actionsRow
                self.confirmButton
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.md)
        }
        .statusBarHidden()
        .onAppear { self.viewModel.trackReviewScreen() }
        .sheet(isPresented: self.$cropShow) {
            if let page = self.viewModel.currentPage {
                ScanCropView(page: page,
                             onSave: { quad in
                                 self.viewModel.setQuad(quad, forPageAt: self.viewModel.currentPageIndex)
                                 self.cropShow = false
                             },
                             onCancel: { self.cropShow = false })
            }
        }
        .sheet(isPresented: self.$filterShow) {
            ScanFilterPickerView(selection: self.currentFilterBinding,
                                 page: self.viewModel.currentPage,
                                 viewModel: self.viewModel,
                                 appliesToAllTitle: String(localized: "Apply to all pages"),
                                 onApplyToAll: { self.viewModel.setFilterForAllPages($0) })
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: self.$organizerShow) {
            ScanPagesOrganizerView(viewModel: self.viewModel)
        }
        .confirmationDialog(Text("Delete this page?"),
                            isPresented: self.$deleteConfirmationShow,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let page = self.viewModel.currentPage else { return }
                withAnimation(DS.Motion.smooth) { self.viewModel.deletePage(id: page.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button {
                self.viewModel.resumeCapture()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .floatingGlassCapsule()
            .accessibilityLabel(Text("Back to the camera"))

            Spacer()

            if self.viewModel.pages.count > 1 {
                Button {
                    self.organizerShow = true
                } label: {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .floatingGlassCapsule()
                .accessibilityLabel(Text("Reorder pages"))
            }

            Button {
                self.viewModel.retakeCurrentPage()
            } label: {
                Text("Retake")
                    .font(forCategory: .button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(height: DS.Size.tapTarget)
            }
            .buttonStyle(.plain)
            .floatingGlassCapsule()
        }
        .padding(.top, DS.Spacing.xs)
    }

    private var pager: some View {
        TabView(selection: self.$viewModel.currentPageIndex) {
            ForEach(Array(self.viewModel.pages.enumerated()), id: \.element.id) { index, page in
                ScanPagePreview(page: page, viewModel: self.viewModel)
                    .padding(.vertical, DS.Spacing.md)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var pageIndicator: some View {
        if self.viewModel.pages.count > 1 {
            Text("Page \(self.viewModel.currentPageIndex + 1) of \(self.viewModel.pages.count)")
                .font(forCategory: .caption1)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, DS.Spacing.sm)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            CameraControlButton(title: String(localized: "Adjust"),
                                systemImage: "crop",
                                isActive: self.viewModel.currentPage?.quad != nil) {
                self.cropShow = true
            }
            CameraControlButton(title: String(localized: "Filters"),
                                systemImage: self.viewModel.currentPage?.filter.systemImage ?? "camera.filters",
                                isActive: (self.viewModel.currentPage?.filter ?? .original) != .original) {
                self.filterShow = true
            }
            CameraControlButton(title: String(localized: "Rotate"),
                                systemImage: "rotate.right") {
                withAnimation(DS.Motion.snappy) { self.viewModel.rotateCurrentPage() }
            }
            CameraControlButton(title: String(localized: "Delete"),
                                systemImage: "trash") {
                self.deleteConfirmationShow = true
            }
        }
        .padding(.bottom, DS.Spacing.md)
    }

    private var confirmButton: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                self.viewModel.resumeCapture()
            } label: {
                Label("Add page", systemImage: "plus")
                    .font(forCategory: .button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(height: 50)
            }
            .buttonStyle(.plain)
            .floatingGlassCapsule()

            Button {
                self.viewModel.finish()
            } label: {
                Text(self.viewModel.mode == .handOff ? String(localized: "Use these pages") : String(localized: "Save"))
                    .font(forCategory: .button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.plain)
            .floatingGlassCapsule(tint: ColorPalette.accent)
        }
    }

    /// Reading and writing the current page's filter as one binding, so the
    /// picker can stay a dumb selection view.
    private var currentFilterBinding: Binding<ScanFilter> {
        Binding(
            get: { self.viewModel.currentPage?.filter ?? self.viewModel.captureFilter },
            set: { self.viewModel.setFilter($0, forPageAt: self.viewModel.currentPageIndex) }
        )
    }
}

// MARK: - Page preview

/// The page as it will be saved. Falls back to the raw capture for the instant
/// before Core Image has caught up, so the pager never shows a hole.
struct ScanPagePreview: View {

    let page: ScannedPage
    @ObservedObject var viewModel: DocumentScanViewModel

    var body: some View {
        Image(uiImage: self.viewModel.preview(for: self.page) ?? self.page.original)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

// MARK: - Reordering

/// Drag pages into the order the document should have. A separate screen on
/// purpose: reordering by dragging thumbnails inside the pager would fight with
/// the swipe that turns the page.
struct ScanPagesOrganizerView: View {

    @ObservedObject var viewModel: DocumentScanViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(self.viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    HStack(spacing: DS.Spacing.sm) {
                        ScanPageThumbnail(page: page, viewModel: self.viewModel)
                            .frame(width: 44, height: 58)
                            .clipShape(.rect(cornerRadius: 6, style: .continuous))
                        Text("Page \(index + 1)")
                            .font(forCategory: .body3)
                            .foregroundStyle(ColorPalette.textPrimary)
                        Spacer()
                    }
                }
                .onMove { source, destination in
                    self.viewModel.movePage(from: source, to: destination)
                }
                .onDelete { offsets in
                    for index in offsets {
                        guard self.viewModel.pages.indices.contains(index) else { continue }
                        self.viewModel.deletePage(id: self.viewModel.pages[index].id)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { self.dismiss() }
                }
            }
        }
    }
}
