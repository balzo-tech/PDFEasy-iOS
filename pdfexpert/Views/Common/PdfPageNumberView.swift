//
//  PdfPageNumberView.swift
//  PdfExpert
//
//  Premium tool UI for stamping page numbers. Lets the user pick an anchor
//  position (3×2 grid of page mock-ups), a number format and a font size, then
//  applies the overlay via `PdfPageNumberViewModel`.
//

import SwiftUI
import Factory

struct PdfPageNumberView: View {

    @StateObject var viewModel: PdfPageNumberViewModel
    @Environment(\.dismiss) var dismiss

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let positionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    self.positionSection
                    self.formatSection
                    self.fontSizeSection
                    Spacer().frame(height: 8)
                    self.getDefaultButton(text: String(localized: "Apply"), onButtonPressed: {
                        self.viewModel.apply(onCompletion: { self.dismiss() })
                    })
                }
                .padding([.leading, .trailing], 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(String(localized: "Page numbers"))
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: { self.dismiss() })
            .asyncView(asyncOperation: self.$viewModel.asyncApply,
                       loadingView: { AnimationType.pdf.view })
        }
        .onAppear(perform: self.viewModel.onAppear)
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionTitle(String(localized: "Position"))
            LazyVGrid(columns: Self.positionColumns, spacing: 12) {
                ForEach(PageNumberPosition.allCases, id: \.self) { position in
                    Button(action: { self.viewModel.position = position }) {
                        PageNumberPositionCell(position: position,
                                               isSelected: self.viewModel.position == position)
                    }
                    .buttonStyle(.plain)
                }
            }
            // Three flexible columns would set the little page mock-ups a hand
            // apart in the readable column: they are a picture of one page's
            // corners, and they only read as that while they sit next to each
            // other. A phone is already narrow enough to leave alone.
            .frame(maxWidth: self.horizontalSizeClass == .regular ? 340 : .infinity,
                   alignment: .leading)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionTitle(String(localized: "Format"))
            Picker(String(localized: "Format"), selection: self.$viewModel.format) {
                Text(verbatim: "1").tag(PageNumberFormat.simple)
                Text(String(localized: "1 of N")).tag(PageNumberFormat.ofTotal)
            }
            .pickerStyle(.segmented)
        }
    }

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionTitle(String(localized: "Font size"))
            Stepper(value: self.$viewModel.fontSize, in: 8...24, step: 1) {
                Text("\(String(localized: "Font size")): \(Int(self.viewModel.fontSize))")
                    .font(forCategory: .body1)
                    .foregroundColor(ColorPalette.primaryText)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(forCategory: .headline)
            .foregroundColor(ColorPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small page mock-up with the sample number "1" drawn at `position`'s anchor.
private struct PageNumberPositionCell: View {

    let position: PageNumberPosition
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: self.alignment) {
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.secondaryBG)
            Text(verbatim: "1")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ColorPalette.primaryText)
                .padding(6)
        }
        .frame(height: 74)
        .aspectRatio(0.77, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(self.isSelected ? ColorPalette.buttonGradientStart : ColorPalette.thirdText,
                        lineWidth: self.isSelected ? 2.5 : 1)
        )
    }

    private var alignment: Alignment {
        switch self.position {
        case .topLeft: return .topLeading
        case .topCenter: return .top
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomCenter: return .bottom
        case .bottomRight: return .bottomTrailing
        }
    }
}
