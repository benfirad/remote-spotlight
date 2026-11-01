import Foundation

public struct RemoteTargetConfig: Codable {
    public var name: String
    public var host: String
    public var rootPath: String

    public init(name: String, host: String, rootPath: String) {
        self.name = name
        self.host = host
        self.rootPath = rootPath
    }
}

public struct AppConfig: Codable {
    public var remoteTargets: [RemoteTargetConfig]
    public var localCacheDbPath: String
    public var cliToolPath: String
    public var searchPrefix: String
    public var hotKeyModifiers: String
    public var hotKeyCode: Int

    public static let shared: AppConfig = {
        let home = NSHomeDirectory()
        let configDir = "\(home)/.config/remote-spotlight"
        let configPath = "\(configDir)/config.json"

        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
            return cfg
        }

        // RM-OS ortamı varsa önbelleği ve CLI'yi kendiliğinden kullan; makineler config.json'dan gelir
        let rmosDb = "\(home)/.cache/rmos/rmos_chunks_fts.db"
        let rmosCli = "\(home)/.local/bin/rmos-remote"

        if FileManager.default.fileExists(atPath: rmosDb) {
            return AppConfig(
                remoteTargets: [
                    RemoteTargetConfig(name: "Remote Workstation", host: "desktop-pc", rootPath: "D:/RM-OS"),
                    RemoteTargetConfig(name: "Home Server", host: "home-server", rootPath: "/srv/rm-os")
                ],
                localCacheDbPath: rmosDb,
                cliToolPath: FileManager.default.fileExists(atPath: rmosCli) ? rmosCli : "/usr/local/bin/remote-spotlight",
                searchPrefix: "rmos-remote search",
                hotKeyModifiers: "option",
                hotKeyCode: 49 // Space
            )
        }

        // Generic public open-source defaults
        return AppConfig(
            remoteTargets: [
                RemoteTargetConfig(name: "Remote Workstation", host: "desktop-pc", rootPath: "D:/Data"),
                RemoteTargetConfig(name: "Home Server", host: "home-server", rootPath: "/mnt/storage")
            ],
            localCacheDbPath: "\(home)/.cache/remote-spotlight/index.db",
            cliToolPath: "/usr/local/bin/remote-spotlight",
            searchPrefix: "search",
            hotKeyModifiers: "option",
            hotKeyCode: 49
        )
    }()
}
