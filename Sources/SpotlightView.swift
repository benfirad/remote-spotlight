import SwiftUI
import AppKit

public struct SpotlightView: View {
    @ObservedObject var engine: RMOSSearchEngine
    var onSelect: (SearchResult) -> Void
    var onReadRemote: (SearchResult) -> Void
    var onCopyCommand: (SearchResult) -> Void
    var onLocateInFinder: (SearchResult, Bool) -> Void
    var onOpenFinderSearch: (SearchResult) -> Void
    var onClose: () -> Void

    public var body: some View {
        ZStack {
            // Katman 1: Gerçek Apple macOS 27 NSGlassEffectView Liquid Glass
            LiquidGlassBackground(variant: .v11, cornerRadius: 24)
                .allowsHitTesting(false)

            // Katman 2: Yüksek Kontrast Perdesi
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
                .allowsHitTesting(false)

            // Katman 3: Etkileşimli Arayüz
            VStack(spacing: 0) {
                // Arama Çubuğu
                HStack(spacing: 10) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color.accentColor)

                    // Silinmeyen Kalıcı rmos-remote search Komut Etiketi
                    HStack(spacing: 4) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 10))
                        Text(AppConfig.shared.searchPrefix)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(Color.accentColor)
                    .cornerRadius(6)

                    // Kullanıcı Arama Alanı
                    NativeSearchField(
                        text: $engine.queryText,
                        placeholder: "Belge, kimlik, fatura, proje veya gerçek ara...",
                        onTextChange: { newValue in
                            engine.search(rawQuery: newValue)
                        },
                        onArrowUp: {
                            if engine.selectedIndex > 0 {
                                engine.selectedIndex -= 1
                            }
                        },
                        onArrowDown: {
                            if engine.selectedIndex < engine.results.count - 1 {
                                engine.selectedIndex += 1
                            }
                        },
                        onEscape: {
                            onClose()
                        },
                        onReturn: {
                            if let item = currentItem {
                                onLocateInFinder(item, true)
                            }
                        }
                    )
                    .frame(height: 28)

                    if !engine.queryText.isEmpty {
                        Button(action: {
                            engine.queryText = ""
                            engine.search(rawQuery: "")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if engine.lastSearchDurationMs > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9))
                            Text(String(format: "%.1f ms", engine.lastSearchDurationMs))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.20))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.55))

                Divider()

                // Ana Gövde: Liste ve Canlı Önizleme
                if engine.results.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.45))
                        Text(engine.statusText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary.opacity(0.85))
                        Text("Hızlı arama örnekleri: pasaport · tie · fatura · kira · copart · fırat · begüm")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        // Sol Liste
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 3) {
                                    ForEach(Array(engine.results.enumerated()), id: \.element.id) { index, item in
                                        ResultRow(
                                            item: item,
                                            isSelected: index == engine.selectedIndex,
                                            onSelect: {
                                                engine.selectedIndex = index
                                            },
                                            onOpen: {
                                                engine.selectedIndex = index
                                                onLocateInFinder(item, true)
                                            }
                                        )
                                        .id(index)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                            }
                            .frame(width: 360)
                            .onChange(of: engine.selectedIndex) { newIndex in
                                withAnimation(.easeInOut(duration: 0.10)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }

                        Divider()

                        // Sağ Canlı Önizleme
                        if let item = currentItem {
                            ResultDetailView(
                                item: item,
                                isOpening: engine.isOpeningFile,
                                openingStatus: engine.openingStatusText,
                                onCopy: { onSelect(item) },
                                onLocateFinder: { onLocateInFinder(item, false) },
                                onOpenFile: { onLocateInFinder(item, true) },
                                onOpenFinderSearch: { onOpenFinderSearch(item) },
                                onReadRemote: { onReadRemote(item) },
                                onCopyCommand: { onCopyCommand(item) }
                            )
                            .id(item.id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack {
                                Spacer()
                                Text("Önizleme için bir sonuç seçin")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                Divider()

                // Alt Kısayol Çubuğu
                HStack(spacing: 14) {
                    if engine.isOpeningFile {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(engine.openingStatusText.isEmpty ? "Dosya açılıyor..." : engine.openingStatusText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.accentColor)
                        }
                    } else {
                        ShortcutTag(key: "↵", label: "Dosyayı Aç")
                        ShortcutTag(key: "⌘F", label: "Finder'da Göster")
                        ShortcutTag(key: "⌘C", label: "Metni Kopyala")
                        ShortcutTag(key: "⌘↵", label: "rmos-remote read")
                        ShortcutTag(key: "ESC", label: "Kapat")
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("RM-OS 20K Chunks · Master")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.60))
            }
        }
        .frame(width: 780, height: 490)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1.0)
        )
    }

    private var currentItem: SearchResult? {
        guard !engine.results.isEmpty else { return nil }
        let idx = min(max(0, engine.selectedIndex), engine.results.count - 1)
        return engine.results[idx]
    }
}

// Result Row Component
struct ResultRow: View {
    let item: SearchResult
    let isSelected: Bool
    var onSelect: () -> Void
    var onOpen: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    DomainBadge(domain: item.domain, colorName: item.domainColorName)

                    Text(item.heading)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Spacer()
                }

                Text(item.snippet.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: ""))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.95) : .secondary)
                    .lineLimit(2)
                    .lineSpacing(2)

                Text(item.loc.isEmpty ? item.source : item.loc)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(isSelected ? .white.opacity(0.80) : .secondary.opacity(0.75))
                    .lineLimit(1)
            }

            if isHovered || isSelected {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : Color.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Dosyayı Aç (↵ veya Çift Tıkla)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            self.isHovered = hovering
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onOpen()
        })
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            onSelect()
        })
    }
}

// Domain Badge
struct DomainBadge: View {
    let domain: String
    let colorName: String

    var color: Color {
        switch colorName {
        case "amber": return .orange
        case "purple": return .purple
        case "teal": return .teal
        case "green": return .green
        case "orange": return .orange
        case "indigo": return .indigo
        case "gray": return .gray
        default: return .blue
        }
    }

    var body: some View {
        Text(domain)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.25))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// Detail View
struct ResultDetailView: View {
    let item: SearchResult
    let isOpening: Bool
    let openingStatus: String
    var onCopy: () -> Void
    var onLocateFinder: () -> Void
    var onOpenFile: () -> Void
    var onOpenFinderSearch: () -> Void
    var onReadRemote: () -> Void
    var onCopyCommand: () -> Void

    private var localPath: String? {
        FileLocator.shared.localPathIfExists(source: item.source, loc: item.loc)
    }

    private var fileIconName: String {
        let name = item.heading.lowercased()
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".md") || name.hasSuffix(".txt") { return "doc.plaintext" }
        if name.hasSuffix(".json") || name.hasSuffix(".jsonl") { return "curlybraces" }
        if name.hasSuffix(".py") || name.hasSuffix(".sh") || name.hasSuffix(".swift") { return "chevron.left.forwardslash.chevron.right" }
        if name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") { return "photo" }
        if name.hasSuffix(".p12") || name.hasSuffix(".key") { return "key.fill" }
        return "doc.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    DomainBadge(domain: item.domain, colorName: item.domainColorName)

                    if localPath != nil {
                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("Bu Mac'te Mevcut")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                    } else {
                        HStack(spacing: 3) {
                            Circle().fill(Color.blue).frame(width: 5, height: 5)
                            Text("RM-OS Ağında")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    }

                    Spacer()

                    if isOpening {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.small)
                            Text(openingStatus.isEmpty ? "Açılıyor..." : openingStatus)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(6)
                    } else {
                        Button(action: onOpenFile) {
                            Label("Aç", systemImage: "arrow.up.forward.app.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .controlSize(.small)
                        .help("Dosyayı Varsayılan Uygulamada Aç (↵)")
                    }

                    Button(action: onLocateFinder) {
                        Label("Finder", systemImage: "folder.badge.gearshape")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Dosyayı Finder'da Göster (⌘F)")

                    Button(action: onOpenFinderSearch) {
                        Label("FinderSearch", systemImage: "sparkle.magnifyingglass")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Klasörü FinderSearch'te Aç")
                }

                HStack(spacing: 8) {
                    Image(systemName: fileIconName)
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)

                    Text(item.heading)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                Text(item.loc.isEmpty ? item.source : item.loc)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Divider()

            // Content preview
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !item.snippet.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EŞLEŞEN ARAMA KESİTİ")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)

                            Text(item.snippet.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: ""))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(8)
                    }

                    if !item.fullContent.isEmpty && item.fullContent != item.snippet {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("İÇERİK ÖNİZLEMESİ")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)

                            Text(item.fullContent)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1.0)
                    )
            )
            .padding(.horizontal, 14)

            Spacer(minLength: 4)

            // Action row
            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Label("Metni Kopyala", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onReadRemote) {
                    Label("rmos-remote read", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onCopyCommand) {
                    Label("Komutu Kopyala", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }
}

// Shortcut Tag
struct ShortcutTag: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.20))
                .cornerRadius(4)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
        }
    }
}
