//
//  PassportPhotoCatalog.swift
//  PdfExpert
//
//  The specifications themselves, one entry per document a person actually has
//  to produce a photograph for.
//
//  The list is deliberately short and checked rather than long and copied. Every
//  size below comes from the issuing authority or from ICAO 9303, which is the
//  document the European sizes descend from; where the authority publishes a
//  frame size but no head height, the range is derived from 9303's "the head
//  occupies 70–80% of the image height" and the note says as much. Nothing here
//  is a guess, and a country nobody has checked is better absent than wrong: the
//  international 35 × 45 entry covers it, and covering it honestly.
//
//  Adding one is four lines and a source. Removing a wrong one is a release.
//

import Foundation
import UIKit

enum PassportPhotoCatalog {

    /// Every specification the app knows, in no particular order — the picker
    /// sorts them and puts the user's own country on top.
    static let all: [PassportPhotoSpec] = [

        // MARK: - The standard everything else descends from

        PassportPhotoSpec(
            id: "icao.35x45",
            regionCode: nil,
            documentName: String(localized: "Standard 35 × 45 mm"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightGrey, .original],
            minimumDPI: 600,
            authority: "ICAO 9303",
            note: String(localized: "The size most of the world uses, including the whole Schengen area."),
            searchTerms: ["icao", "35x45", "schengen", "biometric", "biometrica", "biométrique"]),

        PassportPhotoSpec(
            id: "schengen.visa",
            regionCode: nil,
            documentName: String(localized: "Schengen visa"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.lightGrey, .white, .original],
            minimumDPI: 600,
            authority: "EU Visa Code, ICAO 9303",
            note: String(localized: "Consulates are stricter about the backdrop than about anything else: plain, light, no pattern."),
            searchTerms: ["schengen", "visa", "visto", "visado", "visum"]),

        // MARK: - Europe

        PassportPhotoSpec(
            id: "it.passport",
            regionCode: "IT",
            documentName: String(localized: "Passport and ID card"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightGrey, .original],
            minimumDPI: 600,
            authority: "Ministero degli Affari Esteri · ICAO 9303",
            note: String(localized: "The same photo works for the passport, the electronic ID card and the driving licence."),
            searchTerms: ["fototessera", "foto tessera", "passaporto", "carta d'identità", "cie", "patente"]),

        PassportPhotoSpec(
            id: "es.dni",
            regionCode: "ES",
            documentName: String(localized: "DNI and passport"),
            size: CGSize(width: 26, height: 32),
            faceHeight: 22...26,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .original],
            minimumDPI: 600,
            authority: "Policía Nacional",
            note: String(localized: "Spain is the exception: 26 × 32 mm, not the 35 × 45 mm the rest of Europe uses. Head height derived from ICAO's 70–80% rule."),
            searchTerms: ["foto carnet", "dni", "pasaporte", "nie", "carné"]),

        PassportPhotoSpec(
            id: "fr.passport",
            regionCode: "FR",
            documentName: String(localized: "Passport and ID card"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.lightGrey, .lightBlue, .original],
            minimumDPI: 600,
            authority: "Service-Public.fr · ANTS",
            note: String(localized: "France asks for a plain light background — light grey or light blue. Pure white is refused."),
            searchTerms: ["photo identité", "photo d'identité", "passeport", "cni", "carte d'identité"]),

        PassportPhotoSpec(
            id: "de.passport",
            regionCode: "DE",
            documentName: String(localized: "Biometric passport photo"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.lightGrey, .white, .original],
            minimumDPI: 600,
            authority: "Bundesdruckerei · Bundesministerium des Innern",
            note: String(localized: "A neutral light grey is what the German fotomuster shows; a strong white can wash the outline out."),
            searchTerms: ["passbild", "passfoto", "biometrisch", "personalausweis", "reisepass"]),

        PassportPhotoSpec(
            id: "gb.passport",
            regionCode: "GB",
            documentName: String(localized: "Passport"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 29...34,
            eyeLineFromBottom: nil,
            backgrounds: [.lightGrey, .white, .original],
            minimumDPI: 600,
            authority: "HM Passport Office",
            note: String(localized: "The head is shorter than elsewhere in Europe: 29–34 mm, not 32–36. A photo made to the EU rule is rejected here."),
            searchTerms: ["passport photo", "uk passport", "driving licence"]),

        // MARK: - The Americas

        PassportPhotoSpec(
            id: "us.passport",
            regionCode: "US",
            documentName: String(localized: "Passport and visa"),
            size: CGSize(width: 50.8, height: 50.8),
            faceHeight: 25...35,
            eyeLineFromBottom: 28...35,
            backgrounds: [.white, .original],
            minimumDPI: 300,
            authority: "U.S. Department of State",
            note: String(localized: "Square, 2 × 2 inches, and measured from the eyes rather than from the top of the head."),
            searchTerms: ["passport photo", "visa photo", "id photo", "2x2", "green card", "ds-11"]),

        PassportPhotoSpec(
            id: "ca.passport",
            regionCode: "CA",
            documentName: String(localized: "Passport"),
            size: CGSize(width: 50, height: 70),
            faceHeight: 31...36,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .original],
            minimumDPI: 600,
            authority: "Immigration, Refugees and Citizenship Canada",
            note: String(localized: "The largest frame in this list, 50 × 70 mm, with an ordinary-sized head inside it."),
            searchTerms: ["passport photo", "photo passeport", "ircc"]),

        PassportPhotoSpec(
            id: "br.documento",
            regionCode: "BR",
            documentName: String(localized: "3 × 4 document photo"),
            size: CGSize(width: 30, height: 40),
            faceHeight: 28...32,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .original],
            minimumDPI: 300,
            authority: "Padrão 3 × 4 (RG, CNH, carteira de trabalho)",
            note: String(localized: "The everyday Brazilian document photo. Head height derived from ICAO's 70–80% rule."),
            searchTerms: ["foto 3x4", "3x4", "rg", "cnh", "documento"]),

        PassportPhotoSpec(
            id: "mx.infantil",
            regionCode: "MX",
            documentName: String(localized: "Tamaño infantil"),
            size: CGSize(width: 25, height: 30),
            faceHeight: 19...24,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .original],
            minimumDPI: 300,
            authority: String(localized: "Standard Mexican “infantil” format"),
            note: String(localized: "Nothing to do with children — it is what the small Mexican document photo is called. Head height derived from ICAO's 70–80% rule."),
            searchTerms: ["infantil", "foto credencial", "ine", "pasaporte"]),

        // MARK: - Asia and the Pacific

        PassportPhotoSpec(
            id: "jp.passport",
            regionCode: "JP",
            documentName: String(localized: "Passport"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightGrey, .original],
            minimumDPI: 600,
            authority: "外務省 (Ministry of Foreign Affairs)",
            note: String(localized: "Japan states the head as 34 mm give or take 2 — the same window as the ICAO standard."),
            searchTerms: ["証明写真", "パスポート", "passport photo"]),

        PassportPhotoSpec(
            id: "jp.resume",
            regionCode: "JP",
            documentName: String(localized: "Résumé photo (履歴書)"),
            size: CGSize(width: 30, height: 40),
            faceHeight: 26...32,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightBlue, .lightGrey, .original],
            minimumDPI: 300,
            authority: String(localized: "Standard Japanese résumé format"),
            note: String(localized: "Not an identity document: this is the photo that goes on a Japanese job application, and it is what most people there are looking for."),
            searchTerms: ["履歴書", "証明写真", "就活", "resume", "cv"]),

        PassportPhotoSpec(
            id: "kr.passport",
            regionCode: "KR",
            documentName: String(localized: "Passport"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .original],
            minimumDPI: 600,
            authority: "외교부 (Ministry of Foreign Affairs)",
            note: String(localized: "White only, and both ears should be visible."),
            searchTerms: ["증명사진", "여권사진", "passport photo"]),

        PassportPhotoSpec(
            id: "kr.idphoto",
            regionCode: "KR",
            documentName: String(localized: "ID photo (증명사진)"),
            size: CGSize(width: 30, height: 40),
            faceHeight: 26...32,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightBlue, .original],
            minimumDPI: 300,
            authority: String(localized: "Standard Korean 증명사진 format"),
            note: String(localized: "The one that goes on a résumé, a student card or an application form. Head height derived from ICAO's 70–80% rule."),
            searchTerms: ["증명사진", "이력서", "반명함"]),

        PassportPhotoSpec(
            id: "cn.passport",
            regionCode: "CN",
            documentName: String(localized: "Passport and visa"),
            size: CGSize(width: 33, height: 48),
            faceHeight: 28...33,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightBlue, .original],
            minimumDPI: 300,
            authority: "国家移民管理局 (National Immigration Administration)",
            note: String(localized: "Its own size, 33 × 48 mm, and a light blue backdrop is accepted alongside white."),
            searchTerms: ["签证照片", "护照照片", "visa photo", "passport photo"]),

        PassportPhotoSpec(
            id: "in.passport",
            regionCode: "IN",
            documentName: String(localized: "Passport and OCI"),
            size: CGSize(width: 50.8, height: 50.8),
            faceHeight: 25...35,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .original],
            minimumDPI: 300,
            authority: "Ministry of External Affairs",
            note: String(localized: "Square like the American one, but measured from the crown rather than from the eyes."),
            searchTerms: ["passport photo", "oci", "visa photo", "2x2"]),

        PassportPhotoSpec(
            id: "au.passport",
            regionCode: "AU",
            documentName: String(localized: "Passport"),
            size: CGSize(width: 35, height: 45),
            faceHeight: 32...36,
            eyeLineFromBottom: nil,
            backgrounds: [.white, .lightGrey, .original],
            minimumDPI: 600,
            authority: "Australian Passport Office",
            note: String(localized: "Measured to the crown without the hair, so tall hair does not count towards the 36 mm."),
            searchTerms: ["passport photo", "apo"]),
    ]

    /// The specification to start on: the user's own country if the catalog
    /// knows it, otherwise the international standard.
    ///
    /// Region, not language: someone reading the app in English in Milan needs
    /// the Italian format, and someone reading it in Italian in Boston does not.
    static func `default`(for locale: Locale = .current) -> PassportPhotoSpec {
        if let region = locale.region?.identifier,
           let match = self.all.first(where: { $0.regionCode == region }) {
            return match
        }
        return self.all[0]
    }

    static func spec(withId id: String) -> PassportPhotoSpec? {
        self.all.first { $0.id == id }
    }

    /// The catalog in the order the picker shows it: the user's country first,
    /// then the international entries, then everyone else by country name in the
    /// user's own language — so the list reads alphabetically to the person
    /// looking at it rather than to whoever wrote it.
    static func ordered(for locale: Locale = .current) -> [PassportPhotoSpec] {
        let region = locale.region?.identifier
        let mine = self.all.filter { $0.regionCode != nil && $0.regionCode == region }
        let international = self.all.filter { $0.regionCode == nil }
        let rest = self.all
            .filter { $0.regionCode != nil && $0.regionCode != region }
            .sorted {
                let left = $0.countryName ?? $0.documentName
                let right = $1.countryName ?? $1.documentName
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                    || (left.localizedCaseInsensitiveCompare(right) == .orderedSame
                        && $0.documentName.localizedCaseInsensitiveCompare($1.documentName) == .orderedAscending)
            }
        return mine + international + rest
    }

    /// Free-text search over everything a person might type: the country's name
    /// in their language, the document's name, and the words the App Store says
    /// they search for — `fototessera`, `foto carnet`, `passbild`, `증명사진`.
    static func search(_ query: String, in specs: [PassportPhotoSpec]) -> [PassportPhotoSpec] {
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return specs }
        return specs.filter { spec in
            let haystack = ([spec.documentName, spec.countryName ?? "", spec.regionCode ?? ""] + spec.searchTerms)
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return haystack.contains(needle)
        }
    }
}
