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
              .tint(ReframedColors.primaryText)
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
          .disabled(editorState.isExporting)

        if editorState.isExporting {
          Button("Cancel") { editorState.cancelExport() }
            .buttonStyle(OutlineButtonStyle(size: .small))
        }

        Button("Export") { editorState.showExportSheet = true }
          .buttonStyle(PrimaryButtonStyle(size: .small))
          .disabled(editorState.isExporting)
      }
    }
    .padding(.leading, 16)
    .frame(height: 44)
  }
}
