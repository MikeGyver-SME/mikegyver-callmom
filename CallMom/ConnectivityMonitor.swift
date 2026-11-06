import Foundation
import Network
import Combine

/// Wi-Fi vs cellular vs none, for the cruise-ship warning.
/// NWPathMonitor is the supported API — no private Airplane Mode check exists.
/// We show the reminder text instead of pretending to detect Airplane Mode.
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isWifi = false
    @Published private(set) var isCellular = false
    @Published private(set) var isConnected = false
    @Published private(set) var label = "Checking…"

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "studio.mikegyver.callmom.net")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isWifi = path.usesInterfaceType(.wifi)
                self?.isCellular = path.usesInterfaceType(.cellular)
                if path.status != .satisfied {
                    self?.label = "No connection"
                } else if path.usesInterfaceType(.wifi) {
                    self?.label = "Wi-Fi — good for Google Voice"
                } else if path.usesInterfaceType(.cellular) {
                    self?.label = "Cellular — avoid on the ship"
                } else {
                    self?.label = "Connected"
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
