import SwiftUI

struct EditorTopBar: View {
  @Bindable var editorState: EditorState
  let onOpenFolder: () -> Void
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        Button(action: onOpenFolder) {
          Image(systemName: "folder")
            .font(.system(size: 16))
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ReframedColors.primaryText)

        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.system(size: 16))
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ReframedColors.primaryText)
      }

      Spacer()

      HStack(spacing: 8) {
        Text(editorState.projectName)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)

        if editorState.isExporting {
          HStack(spacing: 6) {
            ProgressView(value: editorState.exportProgress)
              .frame(width: 120)
            Text("\(Int(editorState.exportProgress * 100))%")
              .font(.system(size: 11).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)
          }
        }
      }

      Spacer()

      Button(action: { editorState.showExportSheet = true }) {
        Text("Export")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 20)
          .frame(height: 32)
          .background(Color.blue)
          .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .disabled(editorState.isExporting)
      .opacity(editorState.isExporting ? 0.4 : 1.0)
    }
    .padding(.leading, 16)
    .padding(.trailing, 16)
    .padding(.vertical, 8)
  }
}
