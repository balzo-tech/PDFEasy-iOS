//
//  MemeTemplateCatalog.swift
//  PdfExpert
//
//  The template list behind the meme maker, fetched from memegen.link
//  (api.memegen.link, MIT-licensed project, no key, no account).
//
//  Nothing is bundled. The catalogue and every picture are fetched when the tool
//  is opened and live only in the HTTP cache — the app ships no meme images and
//  redistributes none. That is deliberate: **the rights to the template pictures
//  are stated nowhere** — not in the project, not in the API, not in the guide —
//  and a good part of the upstream catalogue is film and television stills. So
//  the feature is built to be withdrawn: `meme_templates_enabled` turns it off
//  from Firebase without an app update, and `meme_template_ids` narrows the list
//  the same way, should it ever need narrowing.
//
//  Nothing is held back editorially: the whole upstream catalogue is offered,
//  minus only the templates this app cannot draw correctly. `featuredIds` below
//  is an **order**, not a filter — the best-known formats first so the strip
//  opens on something recognisable, then everything else.
//

import Foundation
import UIKit

struct MemeTemplate: Identifiable, Codable, Hashable {

    let id: String
    let name: String
    /// How many lines of text the upstream template expects. Only 1 and 2 are
    /// offered: the on-device renderer draws a top line and a bottom line, and a
    /// template that wants eight would come out wrong rather than plain.
    let lines: Int

    /// The picture with no words on it. Everything is drawn on top of this,
    /// on-device, with our own type — the API's own captioning endpoint is not
    /// used, so the user's words never leave the phone.
    var blankUrl: URL? {
        Self.image(id: self.id, width: 1200)
    }

    var thumbnailUrl: URL? {
        Self.image(id: self.id, width: 240)
    }

    private static func image(id: String, width: Int) -> URL? {
        var components = URLComponents(string: "https://api.memegen.link/images/\(id).jpg")
        components?.queryItems = [URLQueryItem(name: "width", value: String(width))]
        return components?.url
    }
}

/// Fetches and remembers the list. Not a network layer: one GET, one cache.
actor MemeTemplateCatalog {

    static let shared = MemeTemplateCatalog()

    /// The best-known formats, shown first. An **order**, not a filter:
    /// everything else follows these, alphabetically, and nothing is left out.
    ///
    /// Without it the strip would open on whatever happens to sort first
    /// upstream, which is "Three-Headed Dragon".
    static let featuredIds: [String] = [
        "drake", "doge", "cheems", "stonks", "fine", "woman-cat", "rollsafe",
        "blb", "success", "philosoraptor", "yuno", "xy", "buzz", "mordor",
        "morpheus", "spiderman", "wonka", "fry", "away", "disastergirl",
        "oprah", "sparta", "soup-nazi", "aag", "both", "ermg", "jw", "crow"
    ]

    private static let endpoint = URL(string: "https://api.memegen.link/templates")!
    private static let cacheLifetime: TimeInterval = 60 * 60 * 24 * 7

    private var cached: [MemeTemplate]? = nil

    /// Every template the renderer can draw, best-known first.
    ///
    /// The only thing left out is what would come out wrong: this draws a top
    /// line and a bottom line, so a template that expects eight is not offered
    /// rather than offered broken. That is 174 of the 212 upstream.
    ///
    /// `allowedIds` is the remote narrowing, normally empty. Unknown ids are
    /// skipped rather than faked, so a typo there costs one tile and not the
    /// screen.
    func templates(allowedIds: [String] = []) async -> [MemeTemplate] {
        let all = Self.deduplicated(await self.allTemplates().filter { $0.lines <= 2 })
        guard allowedIds.isEmpty else {
            let byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return allowedIds.compactMap { byId[$0] }
        }
        let rank = Dictionary(uniqueKeysWithValues: Self.featuredIds.enumerated().map { ($1, $0) })
        return all.sorted {
            let left = rank[$0.id] ?? Int.max
            let right = rank[$1.id] ?? Int.max
            return left == right ? $0.name < $1.name : left < right
        }
    }

    /// Upstream ships the same id twice for `stonks`, `rollsafe` and `db` — the
    /// pair differs only in whether `source` is filled in. `id` is what makes a
    /// template `Identifiable`, and a `ForEach` given two items with one id draws
    /// one of them and leaves a hole where the other should be: that is what the
    /// gaps in the template grid were, and no amount of sizing was going to fix
    /// them. Deduplicated on the way in, so neither the strip nor the grid has
    /// to know.
    private static func deduplicated(_ templates: [MemeTemplate]) -> [MemeTemplate] {
        var seen = Set<String>()
        return templates.filter { seen.insert($0.id).inserted }
    }

    private func allTemplates() async -> [MemeTemplate] {
        if let cached { return cached }
        if let onDisk = Self.readCache() {
            self.cached = onDisk
            return onDisk
        }
        guard let fetched = await Self.fetch() else { return [] }
        self.cached = fetched
        Self.writeCache(fetched)
        return fetched
    }

    // MARK: - The network, such as it is

    private static func fetch() async -> [MemeTemplate]? {
        do {
            var request = URLRequest(url: Self.endpoint)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode([MemeTemplate].self, from: data)
        } catch {
            // A tool that cannot reach a hobby service is a tool that offers the
            // user's own photograph, which is what it did before templates
            // existed. It is not an error worth a dialog.
            return nil
        }
    }

    // MARK: - The cache

    private static var cacheUrl: URL? {
        try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            .appendingPathComponent("meme-templates.json")
    }

    private static func readCache() -> [MemeTemplate]? {
        guard let url = Self.cacheUrl,
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < Self.cacheLifetime,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([MemeTemplate].self, from: data)
    }

    private static func writeCache(_ templates: [MemeTemplate]) {
        guard let url = Self.cacheUrl, let data = try? JSONEncoder().encode(templates) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Pictures

    /// Downloads a template's blank picture. Goes through `URLSession.shared`,
    /// whose cache honours the month-long `max-age` the CDN sends, so picking the
    /// same template twice costs nothing.
    static func image(at url: URL) async -> UIImage? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
