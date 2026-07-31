//
//  ImportTutorialView.swift
//  PdfExpert
//
//  How to convert a file that lives in another app: three steps, one file making
//  the trip.
//
//  Reached from "New ▸ Convert from any file" and from the empty archive. It is a
//  guide, not a tool — nothing here starts any work, which is why the last button
//  only dismisses.
//
//  Built like the onboarding rather than around a pager: the step index drives the
//  drawing, the words and the dots, and a swipe moves the index. (The pager it
//  replaced was a TabView whose drag gesture had to be blocked to keep the steps in
//  order — an argument the layout no longer needs to have.)
//
//  Every string goes through `String(localized:)`. The three it replaced were plain
//  `String`s, which reach `Text` through the verbatim overload and stayed English
//  in every language.
//

import SwiftUI
import Factory

struct ImportTutorialItem {
    let step: ImportTutorialStep
    let title: String
    let description: String
}

struct ImportTutorialView: View {

    static let items: [ImportTutorialItem] = [
        ImportTutorialItem(
            step: .find,
            title: String(localized: "Start where the file is"),
            description: String(localized: "Open Files, Mail, or whichever app is holding the document — a text file, a spreadsheet, a slide deck.")
        ),
        ImportTutorialItem(
            step: .share,
            title: String(localized: "Tap Share"),
            description: String(localized: "The share button, or \"Open in\" if the file offers that instead.")
        ),
        ImportTutorialItem(
            step: .choose,
            title: String(localized: "Choose \(K.Misc.AppTitle)"),
            description: String(localized: "The file arrives in your archive already converted, ready to sign, compress or send.")
        ),
    ]

    @State private var pageIndex: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The guide always opens at the first step; the parameter is there for the
    /// debug flag that screenshots the other two.
    init(initialStep: Int = 0) {
        self._pageIndex = State(initialValue: initialStep)
    }

    private var pageCount: Int { Self.items.count }

    private var item: ImportTutorialItem { Self.items[self.pageIndex] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ImportTutorialPageView(step: self.item.step,
                                       title: self.item.title,
                                       description: self.item.description)
                .id(self.pageIndex)
                .transition(.asymmetric(
                    insertion: .offset(y: 18).combined(with: .opacity),
                    removal: .offset(y: -14).combined(with: .opacity)))
                .animation(self.stepAnimation, value: self.pageIndex)
                Spacer(minLength: DS.Spacing.lg)
                self.pageIndicator
                Spacer().frame(height: DS.Spacing.xl)
                self.getDefaultButton(text: self.buttonTitle,
                                      onButtonPressed: self.advance)
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorPalette.background)
            .contentShape(.rect)
            .gesture(self.swipe)
            .sensoryFeedback(.selection, trigger: self.pageIndex)
            .addSystemCloseButton(color: ColorPalette.textPrimary, onPress: { self.dismiss() })
            .onAppear() {
                Container.shared.analyticsManager().track(event: .reportScreen(.importTutorial))
            }
        }
        .background(ColorPalette.background)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<self.pageCount, id: \.self) { index in
                let isCurrent = index == self.pageIndex
                Capsule()
                    .fill(isCurrent ? ColorPalette.accent : ColorPalette.accent.opacity(0.25))
                    .frame(width: isCurrent ? 24 : 7, height: 7)
            }
        }
        .frame(height: 24)
        .animation(self.stepAnimation, value: self.pageIndex)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(self.pageIndex + 1) of \(self.pageCount)"))
    }

    /// The last step says what pressing it does, which is close the guide.
    private var buttonTitle: String {
        self.pageIndex + 1 < self.pageCount
            ? String(localized: "Continue")
            : String(localized: "Got it")
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -40 {
                    self.advance()
                } else if value.translation.width > 40 {
                    self.goBack()
                }
            }
    }

    private var stepAnimation: Animation? {
        self.reduceMotion ? nil : .smooth(duration: 0.45)
    }

    private func advance() {
        guard self.pageIndex + 1 < self.pageCount else {
            Container.shared.analyticsManager().track(event: .importTutorialCompleted)
            self.dismiss()
            return
        }
        withAnimation(self.stepAnimation) {
            self.pageIndex += 1
        }
    }

    private func goBack() {
        guard self.pageIndex > 0 else { return }
        withAnimation(self.stepAnimation) {
            self.pageIndex -= 1
        }
    }
}

#Preview("Import tutorial") {
    ImportTutorialView()
}
