import AppKit
import SwiftUI

extension ExportSheet {
  var exportingContent: some View {
    VStack(spacing: 0) {
      if let statusMessage = editorState.exportStatusMessage {
        Text(statusMessage)
          .font(.system(size: FontSize.xs, weight: .medium).monospacedDigit())
          .foregroundStyle(ReframedColors.secondaryText)
          .padding(.top, 32)
          .padding(.bottom, 24)
      } else {
        Text("Exporting…")
          .font(.system(size: FontSize.sm, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
          .padding(.top, 32)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          ProgressView(value: editorState.exportProgress)
            .tint(ReframedColors.primaryText)
            .frame(width: 320)

          HStack(spacing: 12) {
            Text("\(Int(editorState.exportProgress * 100))%")
              .font(.system(size: FontSize.xs).monospacedDigit())
              .foregroundStyle(ReframedColors.secondaryText)

            if let eta = editorState.exportETA, eta > 0 {
              Text("ETA \(formatDuration(seconds: Int(ceil(eta))))")
                .font(.system(size: FontSize.xs).monospacedDigit())
                .foregroundStyle(ReframedColors.secondaryText)
            }
          }
        }
        .padding(.bottom, 24)
      }

      Button("Cancel") {
        editorState.cancelExport()
        phase = .settings
      }
      .buttonStyle(OutlineButtonStyle(size: .small))
      .padding(.bottom, 28)
    }
  }

  var completedContent: some View {
    VStack(spacing: 0) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: FontSize.display))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.top, 28)
        .padding(.bottom, 12)

      Text("Export Successful")
        .font(.system(size: FontSize.sm, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.bottom, 16)

      if let url = editorState.lastExportedURL {
        VStack(spacing: 6) {
          Text(url.lastPathComponent)
            .font(.system(size: FontSize.xs, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)
            .truncationMode(.middle)

          Text(MediaFileInfo.formattedFileSize(url: url))
            .font(.system(size: FontSize.xs))
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

  var failedContent: some View {
    VStack(spacing: 0) {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: FontSize.display))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.top, 28)
        .padding(.bottom, 12)

      Text("Export Failed")
        .font(.system(size: FontSize.sm, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.bottom, 12)

      Text(errorMessage)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)

      HStack(spacing: 12) {
        Button("Back") {
          phase = .settings
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

  func startExport() {
    phase = .exporting
    exportTask = Task {
      do {
        let url = try await editorState.export(settings: settings)
        try Task.checkCancellation()
        editorState.lastExportedURL = url
        phase = .completed
      } catch is CancellationError {
      } catch {
        errorMessage = error.localizedDescription
        phase = .failed
      }
    }
    editorState.exportTask = exportTask
  }

  func copyToClipboard() {
    guard let url = editorState.lastExportedURL else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
  }
}
