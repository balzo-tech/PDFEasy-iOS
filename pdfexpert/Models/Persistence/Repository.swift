//
//  Repository.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 27/03/23.
//

import Foundation

protocol Repository {
    func savePdf(pdf: Pdf) throws -> Pdf
    func getDoPdfExist() throws -> Bool
    func loadPdfs() throws -> [Pdf]
    func delete(pdf: Pdf) throws
    
    func saveSignature(signature: Signature) throws -> Signature
    func getDoSignatureExist() throws -> Bool
    func loadSignatures() throws -> [Signature]
    func delete(signature: Signature) throws
    func delete(signatures: [Signature]) throws
    
    func saveSuggestedFields(suggestedFields: SuggestedFields) throws -> SuggestedFields
    func loadSuggestedFields() throws -> SuggestedFields?

    // Filing. Assigning a folder or a tag goes through these rather than through
    // savePdf: it must not rewrite the document blob nor re-index its text.
    func loadFolders() throws -> [Folder]
    func save(folder: Folder) throws -> Folder
    func delete(folder: Folder) throws
    func setFolder(_ folder: Folder?, for pdf: Pdf) throws -> Pdf

    func loadTags() throws -> [Tag]
    func save(tag: Tag) throws -> Tag
    func delete(tag: Tag) throws
    func setTags(_ tags: [Tag], for pdf: Pdf) throws -> Pdf
}
