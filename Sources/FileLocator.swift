import Foundation
import AppKit

public final class FileLocator {
    public static let shared = FileLocator()
    private let fileManager = FileManager.default
    public let cacheDir: String

    public init() {
        let home = NSHomeDirectory()
        self.cacheDir = "\(home)/.cache/rmos/files"
        try? fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
    }

    public func resolveEffectivePath(source: String, loc: String) -> (cleanLoc: String, fileName: String)? {
        let rawLoc = loc.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = !rawLoc.isEmpty ? rawLoc : rawSource
        guard !target.isEmpty else { return nil }

        let cleanLoc = target.components(separatedBy: "#").first ?? target
        let fileName = (cleanLoc as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty && fileName != "/" && fileName != "." else { return nil }
        return (cleanLoc, fileName)
    }

    public func isValidFile(path: String) -> Bool {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            return !isDir.boolValue
        }
        return false
    }

    public func localPathIfExists(source: String, loc: String) -> String? {
        guard let resolved = resolveEffectivePath(source: source, loc: loc) else { return nil }
        let cleanLoc = resolved.cleanLoc
        let fileName = resolved.fileName
        let home = NSHomeDirectory()

        let rel = cleanLoc.replacingOccurrences(of: "RM-OS/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let localCached = "\(cacheDir)/\(rel)"
        if isValidFile(path: localCached) {
            return localCached
        }

        let flatCached = "\(cacheDir)/\(fileName)"
        if isValidFile(path: flatCached) {
            return flatCached
        }

        let localCandidates = [
            cleanLoc,
            "\(home)/Desktop/\(fileName)",
            "\(home)/Downloads/\(fileName)",
            "\(home)/Documents/\(fileName)",
            "\(home)/Downloads/Faturalar/\(fileName)",
            "\(home)/Downloads/Okul Dosyaları/\(fileName)",
            "\(home)/Downloads/Ortopedik Market/\(fileName)"
        ]

        for candidate in localCandidates {
            if isValidFile(path: candidate) {
                return candidate
            }
        }

        return nil
    }

    public enum OpenMode {
        case revealInFinder
        case openFile
        case openInFinderSearch
    }

    public func locateInFinder(
        source: String,
        loc: String,
        openFile: Bool = false,
        onProgress: ((String) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        locateAndOpen(source: source, loc: loc, mode: openFile ? .openFile : .revealInFinder, onProgress: onProgress, completion: completion)
    }

    public func locateAndOpen(
        source: String,
        loc: String,
        mode: OpenMode = .revealInFinder,
        onProgress: ((String) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let resolved = resolveEffectivePath(source: source, loc: loc) else {
            completion(false, "Geçersiz dosya konumu.")
            return
        }

        if let existing = localPathIfExists(source: source, loc: loc) {
            handleOpen(path: existing, mode: mode)
            completion(true, existing)
            return
        }

        let cleanLoc = resolved.cleanLoc
        let rel = cleanLoc.replacingOccurrences(of: "RM-OS/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let localCached = "\(cacheDir)/\(rel)"

        onProgress?("Ağdan indiriliyor (LOLILE Master / MYA-L11)...")

        DispatchQueue.global(qos: .userInitiated).async {
            let targetDir = (localCached as NSString).deletingLastPathComponent
            try? self.fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

            var candidates: [String] = []

            for target in AppConfig.shared.remoteTargets {
                let root = target.rootPath.hasSuffix("/") ? String(target.rootPath.dropLast()) : target.rootPath
                candidates.append("\(target.host):\(root)/\(rel)")

                let unnumbered = rel.replacingOccurrences(of: "^\\d{2}_", with: "", options: .regularExpression)
                if unnumbered != rel {
                    candidates.append("\(target.host):\(root)/\(unnumbered)")
                }

                let bareName = (rel as NSString).lastPathComponent
                candidates.append("\(target.host):\(root)/\(bareName)")

                if rel.contains("IMMIGRATION_LEGAL") {
                    let eduRel = rel.replacingOccurrences(of: "05_OPERATIONS/IMMIGRATION_LEGAL/", with: "EDUCATION_IMMIGRATION/")
                    candidates.append("\(target.host):\(root)/\(eduRel)")
                }
            }

            var success = false
            for remoteTarget in candidates {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
                p.arguments = ["-q", "-o", "ConnectTimeout=4", remoteTarget, localCached]
                try? p.run()
                p.waitUntilExit()

                if self.isValidFile(path: localCached) {
                    success = true
                    break
                }
            }

            DispatchQueue.main.async {
                if success {
                    self.handleOpen(path: localCached, mode: mode)
                    completion(true, localCached)
                } else {
                    completion(false, "Dosya ağ üzerinde (LOLILE Master / MYA-L11) bulunamadı.")
                }
            }
        }
    }

    private func handleOpen(path: String, mode: OpenMode) {
        let url = URL(fileURLWithPath: path)
        switch mode {
        case .openFile:
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-a", "Preview", path]
                try? p.run()
            } else if ["md", "json", "jsonl", "txt", "csv", "log", "yml", "yaml", "sh", "py", "swift"].contains(ext) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-a", "TextEdit", path]
                try? p.run()
            } else {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = [path]
                try? p.run()
            }
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([url])
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-R", path]
            try? p.run()
        case .openInFinderSearch:
            let appPath = "/Applications/FinderSearch.app"
            if fileManager.fileExists(atPath: appPath) {
                var dirPath = path
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue {
                    dirPath = (path as NSString).deletingLastPathComponent
                }
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-a", appPath, dirPath]
                try? p.run()
            } else {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                p.arguments = ["-R", path]
                try? p.run()
            }
        }
    }
}
