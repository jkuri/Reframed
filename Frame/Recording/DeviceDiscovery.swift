import AVFoundation
import CoreMediaIO
import Foundation
import Logging

struct ExternalDevice: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let modelID: String
}

@MainActor @Observable
final class DeviceDiscovery {
  static let shared = DeviceDiscovery()

  private(set) var availableDevices: [ExternalDevice] = []
  private let logger = Logger(label: "eu.jankuri.frame.device-discovery")
  @ObservationIgnored nonisolated(unsafe) private var connectObserver: NSObjectProtocol?
  @ObservationIgnored nonisolated(unsafe) private var disconnectObserver: NSObjectProtocol?

  private init() {
    enable()
    refreshDevices()
    startMonitoring()
  }

  func enable() {
    var allow: UInt32 = 1
    var address = CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    let status = CMIOObjectSetPropertyData(
      CMIOObjectID(kCMIOObjectSystemObject),
      &address,
      0,
      nil,
      UInt32(MemoryLayout<UInt32>.size),
      &allow
    )
    if status != noErr {
      logger.error("Failed to enable CoreMediaIO screen capture devices: \(status)")
    } else {
      logger.info("CoreMediaIO screen capture devices enabled")
    }
  }

  func refreshDevices() {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.external],
      mediaType: .muxed,
      position: .unspecified
    )
    availableDevices = discovery.devices
      .filter { device in
        let model = device.modelID.lowercased()
        return model.contains("iphone") || model.contains("ipad") || model == "ios device"
      }
      .map { device in
        ExternalDevice(id: device.uniqueID, name: device.localizedName, modelID: device.modelID)
      }
    logger.info("Found \(availableDevices.count) iOS device(s)")
  }

  private func startMonitoring() {
    connectObserver = NotificationCenter.default.addObserver(
      forName: AVCaptureDevice.wasConnectedNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refreshDevices()
      }
    }

    disconnectObserver = NotificationCenter.default.addObserver(
      forName: AVCaptureDevice.wasDisconnectedNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refreshDevices()
      }
    }
  }
}
