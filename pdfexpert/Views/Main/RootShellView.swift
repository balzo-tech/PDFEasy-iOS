//
//  RootShellView.swift
//  PdfExpert
//
//  Picks the shell that fits the window: the tab bar on a phone, the three
//  column split on an iPad. Both are driven by the same coordinator and the same
//  view models, so switching between them — which an iPad does live, whenever
//  the window is resized in Stage Manager or put into Slide Over — costs the
//  user nothing.
//

import SwiftUI
import Factory

struct RootShellView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @InjectedObject(\.mainCoordinator) private var mainCoordinator
    // Owned here rather than inside either shell. Crossing the size-class
    // boundary tears one shell down and builds the other; a view model living in
    // the shell would take the scroll position, the filters and any half-finished
    // tool flow with it.
    @InjectedObject(\.archiveViewModel) private var archive
    @InjectedObject(\.homeViewModel) private var tools
    @InjectedObject(\.chatPdfSelectionViewModel) private var chat

    private var isRegularWidth: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if self.isRegularWidth {
                MainSplitView(archive: self.archive, tools: self.tools, chat: self.chat)
            } else {
                MainTabView(archive: self.archive, tools: self.tools, chat: self.chat)
            }
        }
        .pdfEditFlowView(pdfEditFlowData: self.$mainCoordinator.pdfEditFlowData)
        .settingsView(showSettings: self.$mainCoordinator.settingsShow)
        // The scanner covers everything, from every tab, because every entry
        // point into it — the tab, the tool, a widget, a shortcut — lands here.
        .fullScreenCover(isPresented: self.$mainCoordinator.scanFlowShow) {
            ScanFlowView(mode: .newDocument, onSaved: { _ in
                self.archive.refresh()
            })
        }
    }
}

extension View {

    func pdfEditFlowView(pdfEditFlowData: Binding<PdfEditFlowData?>) -> some View {
        self.fullScreenCover(item: pdfEditFlowData) { data in
            PdfFlowView(
                pdf: data.pdf,
                startAction: data.startAction,
                shouldShowCloseWarning: data.isNewPdf
            )
        }
    }

    func settingsView(showSettings: Binding<Bool>) -> some View {
        self.sheet(isPresented: showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings.wrappedValue = false }
                        }
                    }
            }
        }
    }
}

#Preview {
    RootShellView()
}
