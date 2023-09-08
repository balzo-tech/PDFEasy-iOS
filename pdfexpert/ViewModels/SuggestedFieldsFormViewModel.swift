//
//  SuggestedFieldsFormViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/09/23.
//

import Foundation
import Factory

extension Container {
    var suggestedFieldsFormViewModel: Factory<SuggestedFieldsFormViewModel> {
        self { SuggestedFieldsFormViewModel() }
    }
}

class SuggestedFieldsFormViewModel: ObservableObject {
    
    @Published var firstName: String
    @Published var lastName: String
    
    @Injected(\.analyticsManager) private var analyticsManager
    private let repository = resolve(\.repository)
    
    private var suggestedFields: SuggestedFields
    
    init() {
        self.suggestedFields = (try? self.repository.loadSuggestedFields()) ?? SuggestedFields()
        self._firstName = .init(initialValue: self.suggestedFields.firstName ?? "")
        self._lastName = .init(initialValue: self.suggestedFields.lastName ?? "")
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.suggestedFields))
    }
    
    func onConfirmButtonPressed() {
        self.update(keyPath: \.firstName, value: self.firstName)
        self.update(keyPath: \.lastName, value: self.lastName)
        
        do {
            _ = try self.repository.saveSuggestedFields(suggestedFields: self.suggestedFields)
        } catch {
            debugPrint(for: self, message: "Error: \(error)")
        }
    }
    
    private func update(keyPath: WritableKeyPath<SuggestedFields, String?>, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.suggestedFields[keyPath: keyPath] = trimmedValue.isEmpty ? nil : trimmedValue
    }
}

