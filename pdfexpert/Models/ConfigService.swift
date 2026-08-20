//
//  ConfigService.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 13/04/23.
//

import Foundation
import Combine

protocol ConfigService {
    /// Asks for the configuration once, at launch.
    ///
    /// This exists because `onApplicationDidBecomeActive()` is not enough: on Mac
    /// Catalyst the activation notification never reaches the view that listened
    /// for it, so the app ran an entire session on the in-app defaults — an empty
    /// proxy URL, which silently takes away ChatPDF, the online tools and the
    /// fallback for Office files. Launching is something that always happens.
    func start()
    func onApplicationDidBecomeActive()
    var remoteConfigData: CurrentValueSubject<RemoteConfigData, Never> { get }
}
