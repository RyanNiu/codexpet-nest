import Foundation

protocol MetricProvider {
    var refreshInterval: TimeInterval { get }
    func snapshot() -> MetricSnapshot
}
