//
//  Repository.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 27/03/23.
//

import Foundation
import CoreData

protocol Repository {
    var pdfManagedContext: NSManagedObjectContext { get }
    
    func saveChanges() throws
    func getDoPdfExist() throws -> Bool
    func loadPdfs() throws -> [Pdf]
}
