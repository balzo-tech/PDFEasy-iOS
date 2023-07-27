//
//  Repository.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 27/03/23.
//

import Foundation

protocol Repository {
    func savePdf(pdfEditable: PdfEditable) throws -> PdfEditable
    func getDoPdfExist() throws -> Bool
    func loadPdfs() throws -> [PdfEditable]
    func delete(pdfEditable: PdfEditable) throws
}
