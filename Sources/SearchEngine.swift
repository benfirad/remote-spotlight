import Foundation
import SQLite3
import Combine

public struct SearchResult: Identifiable, Hashable {
    public let id: String
    public let source: String
    public let heading: String
    public let loc: String
    public let snippet: String
    public let fullContent: String
    public let score: Double
    public let domain: String
    public let domainColorName: String

    public init(source: String, heading: String, loc: String, snippet: String, fullContent: String, score: Double) {
        let cleanHeading = heading.isEmpty ? (source.components(separatedBy: "/").last ?? source) : heading
        self.id = "\(source)#\(cleanHeading)#\(loc)"
        self.source = source
        self.heading = cleanHeading
        self.loc = loc
        self.snippet = snippet
        self.fullContent = fullContent
        self.score = score

        // Domain extraction
        let srcUpper = source.uppercased()
        if srcUpper.contains("FACTS") {
            self.domain = "FACTS"
            self.domainColorName = "amber"
        } else if srcUpper.contains("00_CORE") || srcUpper.contains("RULES") || srcUpper.contains("IDENTITY.MD") || srcUpper.contains("STATE.MD") {
            self.domain = "CORE"
            self.domainColorName = "purple"
        } else if srcUpper.contains("02_IDENTITY") || srcUpper.contains("PROFILE") || srcUpper.contains("USER.MD") {
            self.domain = "IDENTITY"
            self.domainColorName = "teal"
        } else if srcUpper.contains("03_BUSINESS") || srcUpper.contains("REDMONO") || srcUpper.contains("RM_GARAGE") || srcUpper.contains("SPAIN_COMPANY") || srcUpper.contains("CLIENT") || srcUpper.contains("ACCOUNTING") {
            self.domain = "BUSINESS"
            self.domainColorName = "green"
        } else if srcUpper.contains("04_PROJECT") || srcUpper.contains("PROJECTS") {
            self.domain = "PROJECTS"
            self.domainColorName = "orange"
        } else if srcUpper.contains("05_OPERATION") || srcUpper.contains("IMMIGRATION") || srcUpper.contains("DEVICE") || srcUpper.contains("VEHICLE") || srcUpper.contains("PASS_AND_IDS") || srcUpper.contains("RENOVACION") {
            self.domain = "OPERATIONS"
            self.domainColorName = "blue"
        } else if srcUpper.contains("06_KNOWLEDGE") || srcUpper.contains("SHARED_WITH_AI") || srcUpper.contains("TOOLS") {
            self.domain = "KNOWLEDGE"
            self.domainColorName = "indigo"
        } else if srcUpper.contains("07_ARCHIVE") || srcUpper.contains("REVIEW") || srcUpper.contains("BACKUP") {
            self.domain = "ARCHIVE"
            self.domainColorName = "gray"
        } else {
            self.domain = "RM-OS"
            self.domainColorName = "blue"
        }
    }
}

public final class RMOSSearchEngine: ObservableObject {
    @Published public var queryText: String = ""
    @Published public var results: [SearchResult] = []
    @Published public var selectedIndex: Int = 0
    @Published public var isSearching: Bool = false
    @Published public var lastSearchDurationMs: Double = 0.0
    @Published public var statusText: String = "Hazır"
    @Published public var isOpeningFile: Bool = false
    @Published public var openingStatusText: String = ""

    private let dbPath: String
    private var db: OpaquePointer?
    private var searchWorkItem: DispatchWorkItem?
    private var lastDbMtime: Date?

    public init() {
        self.dbPath = AppConfig.shared.localCacheDbPath
        openDatabase()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func openDatabase() {
        if let existing = db {
            sqlite3_close(existing)
            db = nil
        }
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            print("RMOSSearchEngine: SQLite veritabanı açılamadı: \(dbPath)")
            db = nil
        } else {
            let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath)
            lastDbMtime = attrs?[.modificationDate] as? Date
        }
    }

    public func checkDatabaseFreshness() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath)
        let currentMtime = attrs?[.modificationDate] as? Date
        if db == nil || (currentMtime != nil && currentMtime != lastDbMtime) {
            openDatabase()
        }
    }

    public func cleanQuery(_ raw: String) -> String {
        var q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixLower = "rmos-remote search"
        if q.lowercased().hasPrefix(prefixLower) {
            q = String(q.dropFirst(prefixLower.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Remove enclosing quotes if any
        if (q.hasPrefix("\"") && q.hasSuffix("\"")) || (q.hasPrefix("'") && q.hasSuffix("'")) {
            q = String(q.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return q
    }

    // Typo corrections and bilingual expansion
    private func expandToken(_ rawToken: String) -> String {
        let t = rawToken.lowercased()
        switch t {
        case "pasaprot", "pasaport", "passport", "pasaporte", "pasaprt":
            return "( \"pasaport\"* OR \"passport\"* OR \"pasaporte\"* )"
        case "kimlik", "id", "dni":
            return "( \"tie\"* OR \"nie\"* OR \"kimlik\"* OR \"dni\"* )"
        case "oturum", "residencia", "ikamet", "ex00":
            return "( \"residencia\"* OR \"oturum\"* OR \"ex00\"* OR \"renovacion\"* )"
        case "fatura", "factura", "invoice", "dekont":
            return "( \"fatura\"* OR \"factura\"* OR \"invoice\"* )"
        case "araba", "arac", "copart", "peugeot", "bmw":
            return "( \"copart\"* OR \"peugeot\"* OR \"bmw\"* OR \"arac\"* OR \"araba\"* )"
        case "ehliyet", "surucu", "conducir":
            return "( \"conducir\"* OR \"ehliyet\"* OR \"permiso\"* )"
        case "kira", "sozlesme", "arrendamiento":
            return "( \"arrendamiento\"* OR \"contrato\"* OR \"kira\"* )"
        case "begum", "begüm":
            return "( \"begum\"* OR \"begüm\"* )"
        case "firat", "fırat":
            return "( \"firat\"* OR \"fırat\"* )"
        default:
            return "\"\(t)\"*"
        }
    }

    public func search(rawQuery: String) {
        searchWorkItem?.cancel()

        let cleaned = cleanQuery(rawQuery)
        if cleaned.isEmpty {
            DispatchQueue.main.async {
                self.results = []
                self.selectedIndex = 0
                self.lastSearchDurationMs = 0
                self.statusText = "Aramak için yazın..."
                self.isSearching = false
            }
            return
        }

        self.isSearching = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.executeSearch(cleaned: cleaned)
        }

        searchWorkItem = workItem
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.035, execute: workItem)
    }

    private func executeSearch(cleaned: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        checkDatabaseFreshness()
        guard let db = db else {
            DispatchQueue.main.async {
                self.statusText = "Veritabanı bulunamadı. Lütfen rmos-remote update-cache çalıştırın."
                self.isSearching = false
            }
            return
        }

        // Tokenize query
        let rawTokens = cleaned.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        if rawTokens.isEmpty {
            DispatchQueue.main.async {
                self.results = []
                self.selectedIndex = 0
                self.isSearching = false
            }
            return
        }

        // Build FTS query with typo tolerance & synonym expansion
        let ftsExpr = rawTokens.map { expandToken($0) }.joined(separator: " AND ")

        // High priority column weights: w(source)=25.0, w(heading)=30.0, w(loc)=1.0, w(content)=1.0
        let sql = """
        SELECT source, heading, loc, snippet(chunks_fts, 3, '⟦', '⟧', '...', 22), bm25(chunks_fts, 25.0, 30.0, 1.0, 1.0), content
        FROM chunks_fts
        WHERE chunks_fts MATCH ?
        ORDER BY bm25(chunks_fts, 25.0, 30.0, 1.0, 1.0) ASC
        LIMIT 80;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("FTS5 prepare error: \(errMsg) for query: \(ftsExpr)")
            DispatchQueue.main.async {
                self.isSearching = false
            }
            return
        }

        sqlite3_bind_text(stmt, 1, (ftsExpr as NSString).utf8String, -1, nil)

        var items: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let source = sqlite3_column_text(stmt, 0) != nil ? String(cString: sqlite3_column_text(stmt, 0)) : ""
            let heading = sqlite3_column_text(stmt, 1) != nil ? String(cString: sqlite3_column_text(stmt, 1)) : ""
            let loc = sqlite3_column_text(stmt, 2) != nil ? String(cString: sqlite3_column_text(stmt, 2)) : ""
            let snippet = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : ""
            let score = sqlite3_column_double(stmt, 4)
            let content = sqlite3_column_text(stmt, 5) != nil ? String(cString: sqlite3_column_text(stmt, 5)) : ""

            items.append(SearchResult(
                source: source,
                heading: heading,
                loc: loc,
                snippet: snippet,
                fullContent: content,
                score: score
            ))
        }
        sqlite3_finalize(stmt)

        // Expanded tokens for relevance scoring (guarantees heading/filename priority)
        let scoringTokens = expandTokensForRelevance(rawTokens)

        items.sort { (a, b) -> Bool in
            let boostA = self.calculateRelevance(item: a, tokens: scoringTokens)
            let boostB = self.calculateRelevance(item: b, tokens: scoringTokens)
            if boostA != boostB {
                return boostA > boostB
            }
            return a.score < b.score // bm25 score: more negative is better
        }

        let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        DispatchQueue.main.async {
            self.results = Array(items.prefix(40))
            self.selectedIndex = 0
            self.lastSearchDurationMs = durationMs
            self.isSearching = false
            self.statusText = "\(self.results.count) sonuç (\(String(format: "%.1f", durationMs)) ms)"
        }
    }

    private func expandTokensForRelevance(_ rawTokens: [String]) -> [String] {
        var set = Set<String>()
        for rt in rawTokens {
            let t = rt.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
            set.insert(t)
            if ["pasaprot", "pasaport", "passport", "pasaporte", "pasaprt"].contains(t) {
                set.formUnion(["pasaport", "passport", "pasaporte"])
            } else if ["kimlik", "id", "dni", "tie", "nie"].contains(t) {
                set.formUnion(["kimlik", "dni", "tie", "nie"])
            } else if ["residencia", "oturum", "ikamet", "ex00"].contains(t) {
                set.formUnion(["residencia", "oturum", "ikamet", "renovacion"])
            } else if ["fatura", "factura", "invoice"].contains(t) {
                set.formUnion(["fatura", "factura", "invoice"])
            } else if ["araba", "arac", "copart", "peugeot", "bmw"].contains(t) {
                set.formUnion(["araba", "arac", "peugeot", "bmw", "copart"])
            }
        }
        return Array(set)
    }

    private func calculateRelevance(item: SearchResult, tokens: [String]) -> Double {
        var boost: Double = 0.0
        let hLower = item.heading.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        let sLower = item.source.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        let fileName = ((item.source as NSString).lastPathComponent).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        let cLower = item.fullContent.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()

        for t in tokens {
            if t.isEmpty { continue }

            // 1. Heading exact match or contains
            if hLower == t {
                boost += 3000.0
            } else if hLower.hasPrefix(t) {
                boost += 2000.0
            } else if hLower.contains(t) {
                boost += 1500.0
            }

            // 2. Filename exact match or contains
            if fileName == t || fileName.hasPrefix(t) {
                boost += 1200.0
            } else if fileName.contains(t) {
                boost += 1000.0
            } else if sLower.contains(t) {
                boost += 500.0
            }

            // 3. Body Content match (lower weight)
            if cLower.contains(t) {
                boost += 25.0
            }
        }
        return boost
    }
}
