//
//  DebugWindowCapture.swift
//  PdfExpert
//
//  Fa sì che l'app fotografi la propria finestra e scriva i PNG su disco.
//
//  Serve quando l'app va guardata ma lo schermo non è raggiungibile: una sessione
//  senza permesso di cattura schermo, un device vero, una macchina bloccata. Il
//  disegno viene dalla UIWindow stessa, quindi non serve alcun permesso di
//  sistema — e per la stessa ragione non compare quello che disegna il sistema
//  *fuori* dalla finestra (su Mac la barra del titolo, su iPhone la status bar).
//
//  Tutto è pilotato da variabili d'ambiente, così non c'è niente da cambiare nel
//  codice per usarlo:
//
//    PDFPRO_CAPTURE_DIR    cartella dove scrivere i PNG (accende lo strumento)
//    PDFPRO_CAPTURE_LABEL  prefisso dei nomi file (default "shot")
//    PDFPRO_CAPTURE_GOTO   "onboarding", oppure il numero di un MainTab
//    PDFPRO_CAPTURE_OPEN   percorso di un file da far aprire all'app all'avvio
//
//  Esiste solo nei build DEBUG.
//

#if DEBUG
import UIKit
import Factory

enum DebugWindowCapture {

    /// Quante fotografie e a che distanza. La prima è tardi di proposito: prima
    /// che la finestra sia montata e le animazioni di apertura finite non c'è
    /// niente da guardare.
    private static let shots = 3
    private static let firstDelay: Duration = .seconds(4)
    private static let interval: Duration = .seconds(3)

    static func startIfRequested() {
        guard let directory = ProcessInfo.processInfo.environment["PDFPRO_CAPTURE_DIR"] else { return }
        let label = ProcessInfo.processInfo.environment["PDFPRO_CAPTURE_LABEL"] ?? "shot"

        Task { @MainActor in
            Self.applyRequestedDestination()
            Self.openRequestedFile()

            for index in 0..<Self.shots {
                try? await Task.sleep(for: index == 0 ? Self.firstDelay : Self.interval)
                Self.capture(into: directory, name: "\(label)-\(index)")
            }
        }
    }

    // MARK: - Pilotaggio

    @MainActor
    private static func applyRequestedDestination() {
        guard let destination = ProcessInfo.processInfo.environment["PDFPRO_CAPTURE_GOTO"] else { return }
        let coordinator = Container.shared.mainCoordinator()
        if destination == "onboarding" {
            coordinator.rootView = .onboarding
            coordinator.showOnboarding()
        } else if let value = Int(destination), let tab = MainTab(rawValue: value) {
            coordinator.rootView = .main
            coordinator.tab = tab
        }
    }

    /// Entra dalla stessa porta di un file aperto dal Finder o da un'altra app,
    /// così quello che si guarda è la pipeline vera e non una scorciatoia.
    @MainActor
    private static func openRequestedFile() {
        guard let path = ProcessInfo.processInfo.environment["PDFPRO_CAPTURE_OPEN"] else { return }
        let url = URL(filePath: path)
        print("[capture] apro \(url.lastPathComponent)")
        Container.shared.mainCoordinator().handleOpenUrl(url: url)
    }

    // MARK: - Fotografia

    /// Fotografa **ogni** finestra, non solo quella principale: un alert di
    /// sistema — `.alert` di SwiftUI, il picker dei file — vive in una UIWindow
    /// sua, sopra le altre. Guardando solo la prima si conclude che l'errore non
    /// viene mostrato, mentre è lì in una finestra che non si stava guardando.
    @MainActor
    private static func capture(into directory: String, name: String) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden && $0.bounds.width > 0 }
        guard !windows.isEmpty else {
            print("[capture] nessuna finestra")
            return
        }
        for (index, window) in windows.enumerated() {
            // La principale tiene il nome nudo; le altre lo numerano, così una
            // cartella di catture resta leggibile.
            let suffix = index == 0 ? "" : "-w\(index)"
            Self.write(window: window, into: directory, name: "\(name)\(suffix)")
        }
    }

    @MainActor
    private static func write(window: UIWindow, into directory: String, name: String) {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            // `drawHierarchy` e non `layer.render`: il secondo salta gli effetti
            // materiali, e mezza interfaccia esce trasparente.
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let data = image.pngData() else { return }
        let url = URL(filePath: directory).appending(path: "\(name).png")
        do {
            try data.write(to: url)
            print("[capture] \(url.path) — \(Int(window.bounds.width))x\(Int(window.bounds.height))")
        } catch {
            print("[capture] scrittura fallita: \(error)")
        }
    }
}
#endif
