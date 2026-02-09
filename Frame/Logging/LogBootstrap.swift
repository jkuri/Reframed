import Foundation
import Logging

enum LogBootstrap {
  static func configure() {
    LoggingSystem.bootstrap { label in
      #if DEBUG
      return StreamLogHandler.standardOutput(label: label)
      #else
      return MultiplexLogHandler([
        StreamLogHandler.standardOutput(label: label),
        RotatingFileLogHandler(label: label),
      ])
      #endif
    }
  }
}
