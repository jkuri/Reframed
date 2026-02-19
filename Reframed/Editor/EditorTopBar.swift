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
        if let statusMessage = editorState.exportStatusMessage {
          Text(statusMessage)
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(ReframedColors.secondaryText)
        } else {
          HStack(spacing: 8) {
            ProgressView(value: editorState.exportProgress)
              .frame(width: 200)
            Text("\(Int(editorState.exportProgress * 100))%")
              .font(.system(size: 11).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: 32, alignment: .trailing)
            Text(editorState.exportETA.map { $0 > 0 ? "ETA \(formatDuration(seconds: Int(ceil($0))))" : "" } ?? "")
              .font(.system(size: 11).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: 72, alignment: .leading)
          }
        }
      } else {
        Text(editorState.projectName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
      }

      HStack(spacing: 8) {
        Spacer()

        IconButton(systemName: "folder", color: ReframedColors.secondaryText, action: onOpenFolder)

        IconButton(systemName: "trash", color: ReframedColors.secondaryText, action: onDelete)

        if editorState.isExporting {
          Button(action: { editorState.cancelExport() }) {
            Text("Cancel")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(ReframedColors.primaryText)
              .padding(.horizontal, 18)
              .frame(height: 28)
              .background(ReframedColors.secondaryText.opacity(0.15))
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
        }

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
        .opacity(editorState.isExporting ? 0.5 : 1.0)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, 16)
    .frame(height: 44)
  }
}
