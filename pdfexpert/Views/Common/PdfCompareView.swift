//
//  PdfCompareView.swift
//  PdfExpert
//
//  Two screens: pick the two documents, then read what changed — as words or as
//  highlighted areas of the page, because a change can be either.
//

import SwiftUI

struct PdfCompareView: ViewModifier {

    @ObservedObject var viewModel: PdfCompareViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .fullScreenCover(isPresented: self.$viewModel.setupShow) {
                PdfCompareSetupView(viewModel: self.viewModel)
            }
            .fullScreenCover(isPresented: self.$viewModel.resultShow) {
                PdfCompareResultView(viewModel: self.viewModel)
            }
            .asyncView(asyncItem: self.$viewModel.asyncCompare)
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
    }
}

// MARK: - Setup

struct PdfCompareSetupView: View {

    @ObservedObject var viewModel: PdfCompareViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.md) {
                    self.slot(title: String(localized: "Original"),
                              pdf: self.viewModel.leftPdf,
                              slot: .left)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ColorPalette.textTertiary)
                    self.slot(title: String(localized: "Changed version"),
                              pdf: self.viewModel.rightPdf,
                              slot: .right)
                    Spacer(minLength: 0)
                    if self.viewModel.isComparing {
                        ProgressView(value: self.viewModel.progress) {
                            Text("Comparing…")
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                    }
                    PrimaryActionButton(title: String(localized: "Compare"),
                                        systemImage: "arrow.left.arrow.right",
                                        isEnabled: self.viewModel.canCompare) {
                        self.viewModel.requestCompare()
                    }
                }
                .padding(DS.Spacing.md)
                .readableColumn()
            }
            .navigationTitle("Compare PDFs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { self.viewModel.cancel() }
                }
            }
        }
    }

    private func slot(title: String, pdf: Pdf?, slot: CompareSlot) -> some View {
        Button {
            self.viewModel.pickDocument(for: slot)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if let pdf, let thumbnail = pdf.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 58)
                        .clipShape(.rect(cornerRadius: 6, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ColorPalette.surfaceElevated)
                        Image(systemName: "doc")
                            .foregroundStyle(ColorPalette.textTertiary)
                    }
                    .frame(width: 44, height: 58)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                    Text(pdf?.displayName ?? String(localized: "Choose a PDF"))
                        .font(forCategory: .body2)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: pdf == nil ? "plus.circle" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(ColorPalette.accent)
            }
            .padding(DS.Spacing.sm)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentCard(radius: DS.Radius.control)
    }
}

// MARK: - Result

struct PdfCompareResultView: View {

    @ObservedObject var viewModel: PdfCompareViewModel

    enum Mode: String, CaseIterable, Identifiable {
        case text, visual
        var id: String { self.rawValue }
        var title: String {
            switch self {
            case .text: return String(localized: "Text")
            case .visual: return String(localized: "Visual")
            }
        }
    }

    #if DEBUG
    // debugCompareMode=visual opens straight on the visual tab (the simulator
    // takes no programmatic taps).
    @State private var mode: Mode = UserDefaults.standard.string(forKey: "debugCompareMode") == "visual"
        ? .visual
        : .text
    #else
    @State private var mode: Mode = .text
    #endif

    private var changedPages: [PageComparison] { self.viewModel.result?.changedPages ?? [] }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                if self.changedPages.isEmpty {
                    ContentUnavailableView {
                        Label("No differences", systemImage: "equal.circle")
                    } description: {
                        Text("These two documents match, page by page.")
                    }
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        Picker("", selection: self.$mode) {
                            ForEach(Mode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, DS.Spacing.md)
                        .readableColumn()

                        // Only the text side is bounded: the visual diff wants
                        // every pixel of a wide window, since reading it means
                        // telling two renderings of the same page apart.
                        switch self.mode {
                        case .text: self.textResults
                        case .visual: self.visualResults
                        }
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }
            .navigationTitle(self.summaryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.viewModel.closeResult() }
                }
            }
        }
    }

    private var summaryTitle: String {
        let count = self.changedPages.count
        return count == 0 ? String(localized: "No differences") : String(localized: "\(count) pages changed")
    }

    // MARK: Text mode

    private var textResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(self.changedPages) { page in
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(self.pageLabel(for: page))
                            .font(forCategory: .caption1)
                            .fontWeight(.semibold)
                            .foregroundStyle(ColorPalette.textSecondary)

                        if page.isAdded {
                            self.noteRow(text: String(localized: "This page is only in the changed version."),
                                         color: ColorPalette.success)
                        } else if page.isRemoved {
                            self.noteRow(text: String(localized: "This page was removed."),
                                         color: ColorPalette.danger)
                        } else if page.textChanges.isEmpty {
                            self.noteRow(text: String(localized: "Only the layout changed — see the Visual tab."),
                                         color: ColorPalette.textSecondary)
                        } else {
                            ForEach(page.textChanges) { change in
                                self.changeRow(change)
                            }
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentCard(radius: DS.Radius.control)
                }
            }
            .padding(DS.Spacing.md)
            .readableColumn()
        }
    }

    private func changeRow(_ change: TextChange) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Image(systemName: change.kind == .added ? "plus.circle.fill" : "minus.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(change.kind == .added ? ColorPalette.success : ColorPalette.danger)
            Text(change.text)
                .font(forCategory: .body3)
                .foregroundStyle(ColorPalette.textPrimary)
                .strikethrough(change.kind == .removed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func noteRow(text: String, color: Color) -> some View {
        Text(text)
            .font(forCategory: .caption1)
            .foregroundStyle(color)
    }

    // MARK: Visual mode

    private var visualResults: some View {
        TabView {
            ForEach(self.changedPages) { page in
                VStack(spacing: DS.Spacing.xs) {
                    ComparePageView(viewModel: self.viewModel, comparison: page)
                    Text(self.pageLabel(for: page))
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                    Text("Touch and hold to see the original")
                        .font(forCategory: .caption2)
                        .foregroundStyle(ColorPalette.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.md)
                // Clears the page dots, which float over the bottom of the tab.
                .padding(.bottom, DS.Spacing.xxl + DS.Spacing.md)
            }
        }
        .tabViewStyle(.page)
    }

    private func pageLabel(for page: PageComparison) -> String {
        if let right = page.rightPageIndex {
            return String(localized: "Page \(right + 1)")
        }
        if let left = page.leftPageIndex {
            return String(localized: "Page \(left + 1) (removed)")
        }
        return ""
    }
}

/// One page of the visual diff: the changed version with the differing areas
/// highlighted, and the original underneath while the finger is down.
struct ComparePageView: View {

    let viewModel: PdfCompareViewModel
    let comparison: PageComparison

    @State private var showingOriginal: Bool = false

    private static let renderWidth: CGFloat = 900

    var body: some View {
        GeometryReader { geometry in
            let side: CompareSlot = self.showingOriginal ? .left : .right
            let image = self.viewModel.pageImage(for: self.comparison,
                                                 side: side,
                                                 width: Self.renderWidth)
                ?? self.viewModel.pageImage(for: self.comparison,
                                            side: side == .left ? .right : .left,
                                            width: Self.renderWidth)
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            if !self.showingOriginal {
                                GeometryReader { imageGeometry in
                                    self.highlight(in: imageGeometry.size)
                                }
                            }
                        }
                        .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(.rect)
            // A press, not a toggle: holding to check the original and letting go
            // keeps the comparison one gesture long.
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in self.showingOriginal = true }
                .onEnded { _ in self.showingOriginal = false })
        }
    }

    /// Draws the changed cells of the grid over the page. The grid is row-major
    /// from the top-left of the page, which is the same origin as this overlay.
    private func highlight(in size: CGSize) -> some View {
        let columns = self.comparison.visualGridColumns
        let rows = columns > 0 ? self.comparison.changedCells.count / columns : 0
        let cellWidth = rows > 0 ? size.width / CGFloat(columns) : 0
        let cellHeight = rows > 0 ? size.height / CGFloat(rows) : 0

        return Canvas { context, _ in
            guard rows > 0 else { return }
            for (index, changed) in self.comparison.changedCells.enumerated() where changed {
                let rect = CGRect(x: CGFloat(index % columns) * cellWidth,
                                  y: CGFloat(index / columns) * cellHeight,
                                  width: cellWidth,
                                  height: cellHeight)
                context.fill(Path(rect), with: .color(ColorPalette.danger.opacity(0.28)))
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func showCompareView(viewModel: PdfCompareViewModel) -> some View {
        self.modifier(PdfCompareView(viewModel: viewModel))
    }
}
