import SwiftUI

struct HoverEffectScope<Content: View>: View {
  @ViewBuilder let content: Content
  @Namespace private var hoverNamespace
  @State private var hoveredID: String?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    content
      .environment(\.hoverNamespace, hoverNamespace)
      .environment(\.hoverID, $hoveredID)
      .background {
        if let hoveredID {
          RoundedRectangle(cornerRadius: 8)
            .fill(ReframedColors.hoverBackground)
            .matchedGeometryEffect(id: hoveredID, in: hoverNamespace, isSource: false)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hoveredID)
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
      }
  }
}

private struct HoverNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

private struct HoverIDKey: EnvironmentKey {
  static let defaultValue: Binding<String?>? = nil
}

extension EnvironmentValues {
  var hoverNamespace: Namespace.ID? {
    get { self[HoverNamespaceKey.self] }
    set { self[HoverNamespaceKey.self] = newValue }
  }
  var hoverID: Binding<String?>? {
    get { self[HoverIDKey.self] }
    set { self[HoverIDKey.self] = newValue }
  }
}

private struct HoverEffectModifier: ViewModifier {
  let id: String
  @Environment(\.hoverNamespace) var namespace
  @Environment(\.hoverID) var hoverID

  func body(content: Content) -> some View {
    if let namespace, let hoverID {
      content
        .matchedGeometryEffect(id: id, in: namespace, isSource: true)
        .onHover { hovering in
          if hovering {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
              hoverID.wrappedValue = id
            }
          } else if hoverID.wrappedValue == id {
            withAnimation(.easeInOut(duration: 0.2)) {
              hoverID.wrappedValue = nil
            }
          }
        }
    } else {
      content
    }
  }
}

extension View {
  func hoverEffect(id: String) -> some View {
    modifier(HoverEffectModifier(id: id))
  }
}
