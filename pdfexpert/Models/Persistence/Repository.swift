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
}
