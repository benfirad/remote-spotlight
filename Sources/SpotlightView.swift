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

    private var isExpanded: Bool {
        !engine.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentItem: SearchResult? {
        guard !engine.results.isEmpty, engine.selectedIndex < engine.results.count else { return nil }
        return engine.results[engine.selectedIndex]
    }

    public var body: some View {
        VStack(spacing: 6) {
            // MARK: - 1. Floating Siri Search Pill (550 x 52)
            HStack(spacing: 12) {
                NativeSearchField(
                    text: $engine.queryText,
                    placeholder: "Search remote disks, servers, or ask AI...",
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
                        if !engine.queryText.isEmpty {
                            engine.queryText = ""
                            engine.search(rawQuery: "")
                        } else {
                            onClose()
                        }
                    },
                    onReturn: {
                        if let item = currentItem {
                            onLocateInFinder(item, true)
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 28)

                if !engine.queryText.isEmpty {
                    Text("— Remote Spotlight (<5ms)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.42))
                        .allowsHitTesting(false)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button(action: {
                        engine.queryText = ""
                        engine.search(rawQuery: "")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.45))
                            .font(.system(size: 15))
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer(minLength: 4)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.48))
                }
            }
            .padding(.horizontal, 20)
            .frame(width: 550, height: 52)
            .background(
                LiquidGlassBackground(variant: .v11, cornerRadius: 26)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(isExpanded ? 0.08 : 0.25), radius: isExpanded ? 6 : 16, x: 0, y: isExpanded ? 1 : 5)

            // MARK: - 2. Floating Siri Results Card
            if isExpanded {
                HStack(alignment: .center, spacing: 0) {
                    // Left Badge: Siri Glowing Magenta/Purple Search Icon
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.65, green: 0.15, blue: 0.75),
                                        Color(red: 0.85, green: 0.20, blue: 0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 44)
                            .shadow(color: Color.purple.opacity(0.75), radius: 10, x: 0, y: 0)

                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 10)
                    .zIndex(1)

                    // Main Results Glass Card
                    VStack(spacing: 0) {
                        if engine.results.isEmpty {
                            VStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white.opacity(0.35))
                                Text(engine.statusText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))
                                Spacer()
                            }
                            .frame(height: 140)
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(spacing: 2) {
                                        ForEach(Array(engine.results.prefix(8).enumerated()), id: \.element.id) { index, item in
                                            SiriResultRow(
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
                                            .id(item.id)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                }
                                .onChange(of: engine.selectedIndex) { newIndex in
                                    if newIndex >= 0 && newIndex < engine.results.count {
                                        let targetId = engine.results[newIndex].id
                                        withAnimation(.easeInOut(duration: 0.08)) {
                                            proxy.scrollTo(targetId, anchor: .center)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 330)
                        }
                    }
                    .frame(width: 450)
                    .background(
                        LiquidGlassBackground(variant: .v11, cornerRadius: 22)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 6)

                    // Right Badge: Dark Glass Microphone Icon
                    ZStack {
                        Capsule()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 28, height: 44)
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.70))
                    }
                    .offset(x: -10)
                    .zIndex(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 550)
        .frame(maxHeight: isExpanded ? 420 : 54)
    }
}

// MARK: - Apple Siri / AI Style Result Row
struct SiriResultRow: View {
    let item: SearchResult
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    private var isPDF: Bool {
        item.source.lowercased().hasSuffix(".pdf")
    }

    private var isActionOrFact: Bool {
        item.domain == "FACTS" || item.source.contains("FACTS.jsonl") || item.source.contains("00_CORE")
    }

    private var subtitleText: String {
        let ext = ((item.source as NSString).pathExtension).uppercased()
        let typeStr = isPDF ? "PDF Document" : (ext.isEmpty ? "Remote Entry" : "\(ext) File")
        let parentDir = ((item.source as NSString).deletingLastPathComponent as NSString).lastPathComponent
        let folderStr = parentDir.isEmpty ? "" : " · 📁 \(parentDir)"
        return "\(typeStr)\(folderStr)"
    }

    var body: some View {
        HStack(spacing: 11) {
            // Left Icon
            if isActionOrFact {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.50, blue: 0.95),
                                    Color(red: 0.05, green: 0.35, blue: 0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)

                    Image(systemName: "at")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.88))

                    if isPDF {
                        Text("PDF")
                            .font(.system(size: 6, weight: .black, design: .rounded))
                            .padding(.horizontal, 2)
                            .padding(.vertical, 0.5)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(2)
                            .offset(x: 2, y: 1)
                    }
                }
                .frame(width: 26, height: 26)
            }

            // Heading & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.heading)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onOpen()
        })
    }
}
