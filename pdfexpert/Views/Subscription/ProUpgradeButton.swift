//
//  ProUpgradeButton.swift
//  PdfExpert
//
//  The way in that does not need a document.
//
//  The paywall lives at the exit: it opens when a document is about to leave
//  the app. That is right for someone in the middle of a job and useless for
//  someone who has already decided to pay — they had to start a job and abandon
//  it halfway just to reach the price. This is the missing door, in the header
//  of every main screen, on both shells.
//
//  It takes itself off the screen once the subscription is on. A "PRO" badge
//  shown to a subscriber is not an offer, it is a bill they have already paid.
//

import SwiftUI
import Factory

struct ProUpgradeButton: View {

    let onTap: () -> Void

    @Injected(\.store) private var store

    /// Read from the store here rather than handed down: the button sits in two
    /// different shells — the phone's navigation bar and the iPad sidebar's —
    /// and neither of them carries a subscription state to pass on.
    @State private var isPremium: Bool = false

    var body: some View {
        // The Group is what keeps `onReceive` attached while the button itself
        // is gone: on the button, the subscription would disappear with it.
        Group {
            if !self.isPremium {
                Button(action: self.onTap) {
                    // Not localized on purpose: "PRO" is the name of the plan,
                    // and `Text(verbatim:)` is how the localization lint is told
                    // that a literal is a name rather than a missing translation.
                    Text(verbatim: "PRO")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        // Three capitals set solid read as one blob at this
                        // size; a little tracking is what makes them a badge.
                        .tracking(0.5)
                }
                // The tint through the style, not a `.background` capsule of our
                // own: a toolbar puts every item inside its own glass container,
                // and a filled shape drawn underneath came out as a white blob
                // welded to the button beside it — three blue letters that read
                // as a broken control rather than as an offer. Asking for the
                // prominent style hands the fill to the same material the bar is
                // made of, so it reads as one deliberate accent in the header.
                .buttonStyle(.glassProminent)
                .tint(ColorPalette.accent)
                // Three letters are a poster, not a sentence: VoiceOver reads
                // out what tapping does instead of spelling the badge.
                .accessibilityLabel(Text("Upgrade to PRO"))
            }
        }
        .onReceive(self.store.isPremium) { self.isPremium = $0 }
    }
}

#Preview("PRO button") {
    NavigationStack {
        Text(verbatim: "Header")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProUpgradeButton(onTap: {})
                }
            }
    }
}
