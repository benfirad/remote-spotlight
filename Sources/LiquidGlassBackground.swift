import SwiftUI
import AppKit

private final class LiquidGlassContainerView: NSView {
    weak var glassView: NSView?
    private var isConfigured = false

    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && !isConfigured {
            isConfigured = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.configureBackdropLayersOnce()
            }
        }
    }

    private func configureBackdropLayersOnce() {
        guard let glassView = glassView, let rootLayer = glassView.layer else { return }
        setBackdropProperties(in: rootLayer)
    }

    private func setBackdropProperties(in layer: CALayer) {
        if NSStringFromClass(type(of: layer)).contains("CABackdropLayer") {
            layer.setValue(true, forKey: "windowServerAware")
            layer.setValue(1.0, forKey: "scale")
        }
        layer.sublayers?.forEach { setBackdropProperties(in: $0) }
    }
}

/// All 20 available Apple liquid‑glass variants in macOS 27.
public enum LiquidGlassVariant: Int, CaseIterable, Identifiable, Sendable {
    case v0 = 0, v1 = 1, v2 = 2, v3 = 3, v4 = 4
    case v5 = 5, v6 = 6, v7 = 7, v8 = 8, v9 = 9
    case v10 = 10, v11 = 11, v12 = 12, v13 = 13, v14 = 14
    case v15 = 15, v16 = 16, v17 = 17, v18 = 18, v19 = 19

    public var id: Int { rawValue }
    public static var defaultVariant: LiquidGlassVariant { .v11 }
}

/// High-performance SwiftUI wrapper for Apple's genuine private liquid-glass material (NSGlassEffectView)
public struct LiquidGlassBackground: NSViewRepresentable {
    private let cornerRadius: CGFloat
    private let variant: LiquidGlassVariant

    public init(variant: LiquidGlassVariant = .defaultVariant, cornerRadius: CGFloat = 24) {
        self.variant = variant
        self.cornerRadius = cornerRadius
    }

    private typealias VariantSetterIMP = @convention(c) (AnyObject, Selector, Int) -> Void

    private func callPrivateVariantSetter(on object: AnyObject, value: Int) {
        let sel = NSSelectorFromString("_setVariant:")
        guard let m = class_getInstanceMethod(object_getClass(object), sel) else { return }
        let imp = method_getImplementation(m)
        let f = unsafeBitCast(imp, to: VariantSetterIMP.self)
        f(object, sel, value)
    }

    public func makeNSView(context: Context) -> NSView {
        let container = LiquidGlassContainerView(frame: .zero)
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true

        if let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassType.init(frame: .zero)
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.setValue(cornerRadius, forKey: "cornerRadius")
            callPrivateVariantSetter(on: glass, value: variant.rawValue)

            glass.wantsLayer = true
            glass.layer?.cornerRadius = cornerRadius
            glass.layer?.masksToBounds = true

            container.addSubview(glass)
            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                glass.topAnchor.constraint(equalTo: container.topAnchor),
                glass.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            container.glassView = glass
            return container
        }

        // Fallback for visual effect view
        let fallback = NSVisualEffectView(frame: .zero)
        fallback.material = .popover
        fallback.blendingMode = .behindWindow
        fallback.state = .active
        fallback.wantsLayer = true
        fallback.layer?.cornerRadius = cornerRadius
        fallback.layer?.masksToBounds = true
        return fallback
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // Zero work on redraws for 100% 120 FPS performance
    }
}
