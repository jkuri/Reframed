import AppKit
import SwiftUI

struct ExportResultSheet: View {
  @Bindable var editorState: EditorState
  @Binding var isPresented: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      if editorState.exportResultIsError {
        errorContent
      } else {
        successContent
      }
    }
    .frame(width: 520)
    .background(ReframedColors.backgroundPopover)
  }

  private var successContent: some View {
    VStack(spacing: 0) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 40))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.top, 28)
        .padding(.bottom, 12)

      Text("Export Successful")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.bottom, 16)

      if let url = editorState.lastExportedURL {
        VStack(spacing: 6) {
          Text(url.lastPathComponent)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)
            .truncationMode(.middle)

          Text(MediaFileInfo.formattedFileSize(url: url))
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
        }
        .padding(.bottom, 24)
      }

      HStack(spacing: 12) {
        Button("Copy to Clipboard") {
          copyToClipboard()
        }
        .buttonStyle(OutlineButtonStyle(size: .small))

        Button("Show in Finder") {
          editorState.openExportedFile()
          isPresented = false
        }
        .buttonStyle(OutlineButtonStyle(size: .small))

        Button("Done") {
          isPresented = false
        }
        .buttonStyle(PrimaryButtonStyle(size: .small))
      }
      .padding(.bottom, 28)
    }
  }

  private var errorContent: some View {
    VStack(spacing: 0) {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 40))
        .foregroundStyle(.red)
        .padding(.top, 28)
        .padding(.bottom, 12)

      Text("Export Failed")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.bottom, 12)

      Text(editorState.exportResultMessage)
        .font(.system(size: 13))
        .foregroundStyle(ReframedColors.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)

      Button("OK") {
        isPresented = false
      }
      .buttonStyle(PrimaryButtonStyle(size: .small))
      .padding(.bottom, 28)
    }
  }

  private func copyToClipboard() {
    guard let url = editorState.lastExportedURL else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
  }
}
