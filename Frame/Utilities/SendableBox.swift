final class SendableBox<T>: @unchecked Sendable {
  let session: T

  init(_ session: T) {
    self.session = session
  }
}
