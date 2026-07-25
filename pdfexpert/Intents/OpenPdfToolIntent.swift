//
//  OpenPdfToolIntent.swift
//  PdfExpert
//
//  Brings the app up on a given tool. Used by Siri, Shortcuts and the widget's
//  quick actions.
//

import AppIntents
import Factory

struct OpenPdfToolIntent: AppIntent {

    static var title: LocalizedStringResource = "Open a PDF tool"
    static var description = IntentDescription("Opens the app on the tool you choose.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Tool")
    var tool: PdfToolEntity

    init() {}

    init(tool: PdfToolEntity) {
        self.tool = tool
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$tool)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let action = HomeAction(identifier: self.tool.id) else {
            throw PdfIntentError.toolUnavailable
        }
        Container.shared.mainCoordinator().runTool(action)
        return .result()
    }
}

/// Opens the app on the saved documents.
struct OpenFilesIntent: AppIntent {

    static var title: LocalizedStringResource = "Open my documents"
    static var description = IntentDescription("Opens the app on your saved PDFs.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Container.shared.mainCoordinator().goToArchive()
        return .result()
    }
}
