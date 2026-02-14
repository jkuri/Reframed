import SwiftUI

struct EditorTopBar: View {
  @Bindable var editorState: EditorState
  let onOpenFolder: () -> Void
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    ZStack {
      if editorState.isExporting {
        HStack(spacing: 8) {
          ProgressView(value: editorState.exportProgress)
            .frame(width: 200)
          Text("\(Int(editorState.exportProgress * 100))%")
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(ReframedColors.secondaryText)
        }
      } else {
        Text(editorState.projectName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
      }

      HStack(spacing: 8) {
        Spacer()

        Button(action: onOpenFolder) {
          Image(systemName: "folder")
            .font(.system(size: 14))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ReframedColors.secondaryText)

        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.system(size: 14))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ReframedColors.secondaryText)

        Button(action: { editorState.showExportSheet = true }) {
          Text("Export")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 28)
            .background(ReframedColors.controlAccentColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(editorState.isExporting)
        .opacity(editorState.isExporting ? 0.4 : 1.0)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, 16)
    .frame(height: 44)
  }
}
