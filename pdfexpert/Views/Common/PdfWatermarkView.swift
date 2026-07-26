//
//  PdfWatermarkView.swift
//  PdfExpert
//
//  Premium tool UI for stamping a text watermark. Lets the user type the
//  watermark text and pick opacity, layout and font size, then applies the
//  overlay via `PdfWatermarkViewModel`.
//

import SwiftUI
import Factory

struct PdfWatermarkView: View {

    @StateObject var viewModel: PdfWatermarkViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ToolScreen(title: String(localized: "Watermark")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    self.textSection
                    self.opacitySection
                    self.layoutSection
                    self.fontSizeSection
                    Spacer().frame(height: 8)
                    self.getDefaultButton(text: String(localized: "Apply"),
                                          enabled: self.viewModel.canApply,
                                          onButtonPressed: {
                        self.viewModel.apply(onCompletion: { self.dismiss() })
                    })
                }
                .padding([.leading, .trailing], 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .readableColumn()
            }
            .background(ColorPalette.primaryBG)
            .asyncView(asyncOperation: self.$viewModel.asyncApply,
                       loadingView: { AnimationType.pdf.view })
        }
        .onAppear(perform: self.viewModel.onAppear)
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionTitle(String(localized: "Watermark text"))
            TextField(String(localized: "Enter watermark text"), text: self.$viewModel.text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    private var opacitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                self.sectionTitle(String(localized: "Opacity"))
                Text("\(Int(self.viewModel.opacity * 100))%")
                    .font(forCategory: .body1)
                    .foregroundColor(ColorPalette.primaryText)
            }
            Slider(value: self.$viewModel.opacity, in: 0.1...1.0)
                .tint(ColorPalette.buttonGradientStart)
        }
    }

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionTitle(String(localized: "Layout"))
            Picker(String(localized: "Layout"), selection: self.$viewModel.layout) {
                Text(String(localized: "Diagonal")).tag(WatermarkLayout.diagonal)
                Text(String(localized: "Horizontal")).tag(WatermarkLayout.horizontal)
            }
            .pickerStyle(.segmented)
        }
    }

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.sectionTitle(String(localized: "Font size"))
            Stepper(value: self.$viewModel.fontSize, in: 24...96, step: 2) {
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
