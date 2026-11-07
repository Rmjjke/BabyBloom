import XCTest
import SwiftUI
import Accessibility

/// What VoiceOver finds in a hosted SwiftUI view: each element's label, value
/// and frame, in the order the accessibility tree lists them.
///
/// The tree proves only what is there. An element hidden from VoiceOver is
/// absent here, but whether VoiceOver itself stays silent on that spot is a
/// look on a device.
@MainActor
final class HostedAccessibility {

    struct Element: CustomStringConvertible {
        let label: String
        let value: String
        /// In the window's coordinates.
        let frame: CGRect

        var description: String {
            "\(label) | \(value) | x \(Int(frame.minX))…\(Int(frame.maxX)) y \(Int(frame.minY))…\(Int(frame.maxY))"
        }
    }

    private var windows: [UIWindow] = []

    /// Hides every window this instance opened; call it from `tearDown`.
    func close() {
        windows.forEach { $0.isHidden = true }
        windows = []
    }

    /// The view at `size` in a window of its own, settled. `bold` turns Bold
    /// Text on for the window: an environment `legibilityWeight` does not reach
    /// the views a NavigationStack hosts, the window's trait does.
    func host<V: View>(_ view: V, size: CGSize, bold: Bool = false) throws -> UIView {
        try Self.enableAccessibility()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        if bold {
            window.traitOverrides.legibilityWeight = .bold
        }
        let controller = UIHostingController(rootView: view)
        window.rootViewController = controller
        window.isHidden = false
        windows.append(window)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        return controller.view
    }

    /// SwiftUI builds a hosted view's accessibility elements only while an
    /// assistive client is on; a freshly booted simulator has none.
    private static func enableAccessibility() throws {
        let library = try XCTUnwrap(dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
                                    "libAccessibility did not load: the elements cannot be read")
        let symbol = try XCTUnwrap(dlsym(library, "_AXSApplicationAccessibilitySetEnabled"),
                                   "_AXSApplicationAccessibilitySetEnabled is gone from libAccessibility")
        typealias SetEnabled = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(true)
    }

    // MARK: Reading

    /// `automation` also reads the elements a combined element keeps for UI
    /// tests, as Maestro and XCUITest see them: a List row reads as one
    /// element to VoiceOver, its texts each with a frame of their own here.
    func elements(_ root: UIView, automation: Bool = false) -> [Element] {
        var seen = Set<ObjectIdentifier>()
        var out: [Element] = []
        collect(root, automation: automation, seen: &seen, into: &out)
        return out
    }

    /// Every chart summary in the tree — what the Audio Graph rotor describes.
    func chartDescriptors(_ root: UIView) -> [AXChartDescriptor] {
        var seen = Set<ObjectIdentifier>()
        var out: [AXChartDescriptor] = []
        func walk(_ node: NSObject) {
            guard seen.insert(ObjectIdentifier(node)).inserted else { return }
            if let descriptor = (node as? AXChart)?.accessibilityChartDescriptor { out.append(descriptor) }
            children(of: node).forEach(walk)
        }
        walk(root)
        return out
    }

    private func collect(_ root: NSObject, automation: Bool, seen: inout Set<ObjectIdentifier>,
                         into out: inout [Element]) {
        guard seen.insert(ObjectIdentifier(root)).inserted else { return }
        if root.isAccessibilityElement {
            out.append(Element(label: root.accessibilityLabel ?? "",
                               value: root.accessibilityValue ?? "",
                               frame: root.accessibilityFrame))
        }
        for child in children(of: root, automation: automation) {
            collect(child, automation: automation, seen: &seen, into: &out)
        }
    }

    private func children(of root: NSObject, automation: Bool = false) -> [NSObject] {
        var out: [NSObject] = []
        if automation, let elements = root.automationElements {
            out += elements.compactMap { $0 as? NSObject }
        }
        if let elements = root.accessibilityElements {
            out += elements.compactMap { $0 as? NSObject }
        } else {
            let count = root.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                for i in 0..<count {
                    if let element = root.accessibilityElement(at: i) as? NSObject { out.append(element) }
                }
            }
        }
        if let view = root as? UIView { out += view.subviews }
        return out
    }
}

extension AXChartDescriptor {
    /// Title, summary, both axes and each series' name, on one line.
    var readout: String {
        func axis(_ descriptor: (any AXDataAxisDescriptor)?) -> String {
            guard let descriptor else { return "none" }
            if let numeric = descriptor as? AXNumericDataAxisDescriptor {
                let ends = [numeric.range.lowerBound, numeric.range.upperBound].map(numeric.valueDescriptionProvider)
                return "\(numeric.title) [\(ends.joined(separator: " … "))]"
            }
            if let categorical = descriptor as? AXCategoricalDataAxisDescriptor {
                return "\(categorical.title) [\(categorical.categoryOrder.joined(separator: ", "))]"
            }
            return descriptor.title
        }
        let series = series.map { "\($0.name ?? "") (\($0.dataPoints.count))" }.joined(separator: ", ")
        return "title \(title ?? "none") | summary \(summary ?? "none") | x \(axis(xAxis)) | y \(axis(yAxis)) | series \(series)"
    }
}
