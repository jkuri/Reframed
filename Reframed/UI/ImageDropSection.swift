import SwiftUI
import UniformTypeIdentifiers

struct ImageDropSection: View {
  let image: NSImage?
  let onPick: () -> Void
  let onDrop: (URL) -> Void

  @State private var isDropTargeted = false

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      if let image {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: 60)
          .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
      }
      Button {
        onPick()
      } label: {
        HStack {
          Image(systemName: "photo.on.rectangle")
          Text(LocalizedStringKey(image != nil ? "Change Image" : "Choose Image"))
        }
        .font(.system(size: FontSize.xs))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(ReframedColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
          RoundedRectangle(cornerRadius: Radius.md)
            .strokeBorder(
              isDropTargeted ? Color.accentColor : ReframedColors.border,
              style: isDropTargeted ? StrokeStyle(lineWidth: 1.5, dash: [5, 3]) : StrokeStyle(lineWidth: 1)
            )
        )
      }
      .buttonStyle(PlainCustomButtonStyle())
      .foregroundStyle(ReframedColors.primaryText)
    }
    .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers in
      guard let provider = providers.first else { return false }
      let supportedTypes: [UTType] = [.png, .jpeg, .heic, .tiff]
      for type in supportedTypes {
        if provider.hasRepresentationConforming(toTypeIdentifier: type.identifier) {
          provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
            guard let url else { return }
            let tempDir = FileManager.default.temporaryDirectory
            let dest = tempDir.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
            DispatchQueue.main.async {
              onDrop(dest)
            }
          }
          return true
        }
      }
      return false
    }
  }
}
