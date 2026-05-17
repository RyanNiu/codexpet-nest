import Foundation
import CoreGraphics

// MARK: - Registry Top-Level

struct ComponentRegistry: Codable {
    let schemaVersion: String
    let registryVersion: String
    let metricsVersion: String?
    let rendererPrimitivesVersion: String?
    let minDesktopRuntime: String?
    let components: [ComponentDefinition]

    // MARK: - Validation

    func validate(currentVersion: String) throws {
        if let minVersion = minDesktopRuntime, isVersion(currentVersion, olderThan: minVersion) {
            throw RegistryValidationError.unsupportedRuntime(
                "Nest requires desktop version >= \(minVersion). Current: \(currentVersion)")
        }

        let knownPrimitives = RendererPrimitiveRegistry.allPrimitives

        for component in components {
            // Validate component id format
            guard component.id.hasPrefix("official.") else {
                throw RegistryValidationError.invalidComponentId(component.id)
            }

            // Validate runtime metrics exist in catalog
            try validateRuntimeNode(component.runtime, componentId: component.id, knownPrimitives: knownPrimitives)
        }
    }

    private func validateRuntimeNode(_ node: RuntimeNode, componentId: String, knownPrimitives: Set<String>) throws {
        guard knownPrimitives.contains(node.renderer) else {
            throw RegistryValidationError.unknownPrimitive(
                "Component '\(componentId)': unknown renderer '\(node.renderer)'")
        }

        // Validate only metrics referenced directly by this node. Child metrics
        // are checked against each child's own renderer during recursion.
        if let metricId = node.metric {
            guard MetricCatalog.shared.contains(metricId) else {
                throw RegistryValidationError.unknownMetric(
                    "Component '\(componentId)': unknown metric '\(metricId)'")
            }
            guard MetricCatalog.shared.isMetricAllowedForRenderer(metricId, renderer: node.renderer) else {
                throw RegistryValidationError.incompatibleRenderer(
                    "Component '\(componentId)': metric '\(metricId)' incompatible with renderer '\(node.renderer)'")
            }
        }

        // Recurse into children
        for child in node.children ?? [] {
            try validateRuntimeNode(child, componentId: componentId, knownPrimitives: knownPrimitives)
        }
    }

    // MARK: - Lookup

    func component(id: String) -> ComponentDefinition? {
        components.first { $0.id == id }
    }
}

enum RegistryValidationError: Error, LocalizedError {
    case unsupportedRuntime(String)
    case unknownPrimitive(String)
    case unknownMetric(String)
    case incompatibleRenderer(String)
    case invalidComponentId(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedRuntime(let msg): return msg
        case .unknownPrimitive(let msg): return msg
        case .unknownMetric(let msg): return msg
        case .incompatibleRenderer(let msg): return msg
        case .invalidComponentId(let msg): return "Invalid component id: \(msg)"
        }
    }
}

// MARK: - Component Definition

struct ComponentDefinition: Codable, Equatable {
    let id: String
    let displayName: String
    let category: String?
    let status: String?
    let defaultFrame: RegistryFrame
    let defaultProps: [String: RegistryPropValue]?
    let propsSchema: JSONSchema?
    let runtime: RuntimeNode
    let preview: ComponentPreview?

    /// Resolve effective frame: defaultFrame overlaid with optional instance overrides.
    func effectiveFrame(instanceFrame: NestRect?) -> CGRect {
        let w = instanceFrame?.width ?? defaultFrame.width
        let h = instanceFrame?.height ?? defaultFrame.height
        return CGRect(x: 0, y: 0, width: w, height: h)
    }

    /// Resolve effective props: defaultProps merged with instance props.
    func effectiveProps(instanceProps: [String: NestPropValue]?) -> [String: RegistryPropValue] {
        var merged = defaultProps ?? [:]
        guard let instance = instanceProps else { return merged }
        for (key, val) in instance {
            merged[key] = RegistryPropValue.from(nestProp: val)
        }
        return merged
    }
}

struct RegistryFrame: Codable, Equatable {
    let width: Double
    let height: Double
}

struct JSONSchema: Codable, Equatable {
    let type: String?
    let properties: [String: PropSchemaEntry]?
    let additionalProperties: Bool?
}

struct PropSchemaEntry: Codable, Equatable {
    let type: String?
    let minimum: Double?
    let maximum: Double?
    let pattern: String?
    let `enum`: [String]?
    let `default`: RegistryPropValue?
}

struct ComponentPreview: Codable, Equatable {
    let renderer: String?
    let values: [String: RegistryPropValue]?
    let metrics: [String: RegistryPropValue]?
}

// MARK: - Runtime Node

struct RuntimeNode: Codable, Equatable {
    let renderer: String
    let kind: String?
    let metric: String?
    let props: [String: RegistryPropValue]?
    let children: [RuntimeNode]?

    private enum CodingKeys: String, CodingKey {
        case renderer
        case kind
        case metric
        case props
        case children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedKind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.kind = decodedKind
        self.renderer = try container.decodeIfPresent(String.self, forKey: .renderer) ?? decodedKind ?? ""
        self.metric = try container.decodeIfPresent(String.self, forKey: .metric)
        self.props = try container.decodeIfPresent([String: RegistryPropValue].self, forKey: .props)
        self.children = try container.decodeIfPresent([RuntimeNode].self, forKey: .children)
    }

    init(
        renderer: String,
        kind: String? = nil,
        metric: String? = nil,
        props: [String: RegistryPropValue]? = nil,
        children: [RuntimeNode]? = nil
    ) {
        self.renderer = renderer
        self.kind = kind
        self.metric = metric
        self.props = props
        self.children = children
    }

    /// Collect all metric ids referenced in this node tree.
    var allMetricIds: [String] {
        var ids: [String] = []
        if let m = metric { ids.append(m) }
        for child in children ?? [] {
            ids.append(contentsOf: child.allMetricIds)
        }
        return ids
    }
}

// MARK: - Registry Prop Value

enum RegistryPropValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported prop value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }

    var stringValue: String? { if case .string(let v) = self { return v } else { return nil } }
    var numberValue: Double? { if case .number(let v) = self { return v } else { return nil } }
    var boolValue: Bool? { if case .bool(let v) = self { return v } else { return nil } }

    static func from(nestProp: NestPropValue) -> RegistryPropValue {
        switch nestProp {
        case .string(let v): return .string(v)
        case .number(let v): return .number(v)
        case .bool(let v): return .bool(v)
        }
    }
}

// MARK: - Resolved Props (after $props / $frame resolution)

struct ResolvedRuntimeProps {
    let values: [String: RegistryPropValue]

    func string(_ key: String) -> String? { values[key]?.stringValue }
    func number(_ key: String) -> Double? { values[key]?.numberValue }
    func bool(_ key: String) -> Bool? { values[key]?.boolValue }
    func cgFloat(_ key: String, default: CGFloat = 0) -> CGFloat {
        if let n = number(key) { return CGFloat(n) }
        return `default`
    }
}

extension RuntimeNode {
    /// Resolve props by substituting $props.* and $frame.* references.
    func resolvedProps(effectiveProps: [String: RegistryPropValue], frame: CGRect) -> ResolvedRuntimeProps {
        var resolved: [String: RegistryPropValue] = [:]

        for (key, value) in props ?? [:] {
            if case .string(let ref) = value, ref.hasPrefix("$") {
                resolved[key] = resolveRef(ref, effectiveProps: effectiveProps, frame: frame)
            } else {
                resolved[key] = value
            }
        }

        return ResolvedRuntimeProps(values: resolved)
    }

    private func resolveRef(_ ref: String, effectiveProps: [String: RegistryPropValue], frame: CGRect) -> RegistryPropValue {
        if ref.hasPrefix("$props.") {
            let propKey = String(ref.dropFirst("$props.".count))
            if let v = effectiveProps[propKey] { return v }
            return .string("")
        }
        if ref == "$frame.width" {
            return .number(Double(frame.width))
        }
        if ref == "$frame.height" {
            return .number(Double(frame.height))
        }
        return .string(ref)
    }
}

// MARK: - Primitive Registry

enum RendererPrimitiveRegistry {
    static let allPrimitives: Set<String> = [
        "metricText",
        "linearBar",
        "circleFill",
        "ringStroke",
        "variantIcon",
        "analogClock",
        "timerText",
        "actionButtons",
        "group"
    ]
}
// MARK: - Semver Helpers

private func isVersion(_ v1: String, olderThan v2: String) -> Bool {
    let parts1 = v1.split(separator: ".").compactMap { Int($0) }
    let parts2 = v2.split(separator: ".").compactMap { Int($0) }

    for i in 0..<max(parts1.count, parts2.count) {
        let p1 = i < parts1.count ? parts1[i] : 0
        let p2 = i < parts2.count ? parts2[i] : 0
        if p1 < p2 { return true }
        if p1 > p2 { return false }
    }
    return false
}
