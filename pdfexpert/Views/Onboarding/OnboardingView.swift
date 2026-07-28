//
//  OnboardingView.swift
//  PdfExpert
//
//  Four steps on one stage.
//
//  There is no pager here any more. The document in `OnboardingIllustrationView`
//  is a single view that moves between the steps, so paging it would mean
//  sliding four copies of it past each other and losing exactly the thing worth
//  watching. Instead the step index drives everything: the stage rearranges, the
//  words are replaced, the dots slide. Swiping still works — it just moves the
//  index rather than a scroll offset.
//
//  (The pager it replaced was PagerTabStripView, which had stopped following its
//  own `selection` binding past the third page: the dots moved on while the page
//  underneath snapped back to the first one.)
//

import SwiftUI
import Factory

struct OnboardingView: View {

    @InjectedObject(\.onboardingViewModel) var viewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pageCount: Int { self.viewModel.items.count }

    private var item: OnboardingItem { self.viewModel.items[self.viewModel.pageIndex] }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingIllustrationView(illustration: self.item.illustration)
                .frame(maxWidth: .infinity, maxHeight: 320)
                .layoutPriority(-1)
            Spacer(minLength: DS.Spacing.lg)
            self.copy
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
        .sensoryFeedback(.selection, trigger: self.viewModel.pageIndex)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.viewModel.skipButtonPressed() }) {
                    Text("Skip")
                }
                .tint(ColorPalette.accent)
            }
        }
        .onAppear() {
            Container.shared.analyticsManager().track(event: .reportScreen(.onboarding))
        }
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.onMonetizationClose()
            })
        }
    }

    /// Title and sentence, replaced rather than crossfaded: the outgoing words
    /// blur away upward and the new ones rise into place, which reads as one
    /// sentence being swapped for another instead of two sentences overlapping.
    private var copy: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(self.item.title)
                .font(forCategory: .title1)
                .foregroundStyle(ColorPalette.textPrimary)
            Text(self.item.description)
                .font(forCategory: .body1)
                .foregroundStyle(ColorPalette.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .id(self.viewModel.pageIndex)
        .transition(.asymmetric(
            insertion: .offset(y: 18).combined(with: .opacity),
            removal: .offset(y: -14).combined(with: .opacity)))
        .animation(self.stepAnimation, value: self.viewModel.pageIndex)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<self.pageCount, id: \.self) { index in
                let isCurrent = index == self.viewModel.pageIndex
                Capsule()
                    .fill(isCurrent ? ColorPalette.accent : ColorPalette.accent.opacity(0.25))
                    .frame(width: isCurrent ? 24 : 7, height: 7)
            }
        }
        .frame(height: 24)
        .animation(self.stepAnimation, value: self.viewModel.pageIndex)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(self.viewModel.pageIndex + 1) of \(self.pageCount)"))
    }

    /// The last step says what it will actually do, which is leave the tour.
    private var buttonTitle: String {
        self.viewModel.pageIndex + 1 < self.pageCount
            ? String(localized: "Continue")
            : String(localized: "Get started")
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
        withAnimation(self.stepAnimation) {
            self.viewModel.continueButtonPressed()
        }
    }

    private func goBack() {
        guard self.viewModel.pageIndex > 0 else { return }
        withAnimation(self.stepAnimation) {
            self.viewModel.pageIndex -= 1
        }
    }
}

#Preview("Onboarding") {
    NavigationStack {
        OnboardingView()
    }
}
