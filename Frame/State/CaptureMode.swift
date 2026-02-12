enum CaptureMode: String, Sendable, Equatable, Codable {
  case none = "none"
  case entireScreen = "entireScreen"
  case selectedWindow = "selectedWindow"
  case selectedArea = "selectedArea"
  case device = "device"
}
