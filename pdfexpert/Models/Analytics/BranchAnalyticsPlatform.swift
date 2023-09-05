//
//  BranchAnalyticsPlatform.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 05/09/23.
//

import Foundation
import BranchSDK

class BranchAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .checkoutCompleted(let subscriptionPlanProduct):
            let branchUniversalObject = BranchUniversalObject()
            branchUniversalObject.canonicalIdentifier = subscriptionPlanProduct.id
            branchUniversalObject.contentMetadata.price = NSDecimalNumber(decimal: subscriptionPlanProduct.price)
            branchUniversalObject.title = subscriptionPlanProduct.displayName
            branchUniversalObject.contentMetadata.quantity = 1
            branchUniversalObject.contentMetadata.productName = subscriptionPlanProduct.displayName
            branchUniversalObject.contentMetadata.currency = BNCCurrency(rawValue: subscriptionPlanProduct.priceFormatStyle.currencyCode)
            if subscriptionPlanProduct.isFreeTrial {
                BranchEvent.standardEvent(.startTrial, withContentItem: branchUniversalObject).logEvent()
            } else {
                BranchEvent.standardEvent(.subscribe, withContentItem: branchUniversalObject).logEvent()
            }
        case .reportNonFatalError:
            break
        default:
            self.sendEvent(withEventName: event.customEventName, parameters: event.parameters)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        if let parameters {
            let branchUniversalObject = BranchUniversalObject(dictionary: parameters)
            BranchEvent.customEvent(withName: eventName, contentItem: branchUniversalObject).logEvent()
        } else {
            BranchEvent.customEvent(withName: eventName).logEvent()
        }
    }
}
