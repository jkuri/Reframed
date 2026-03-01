import SwiftUI

struct HistoryPopover: View {
  @Bindable var editorState: EditorState

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "History")

      if editorState.history.entries.isEmpty {
        Text("No history")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.tertiaryText)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 16)
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 2) {
              ForEach(Array(editorState.history.entries.enumerated().reversed()), id: \.offset) {
                index,
                entry in
                let isCurrent = index == editorState.history.currentIndex
                let isFuture = index > editorState.history.currentIndex
                historyRow(entry: entry, index: index, isCurrent: isCurrent, isFuture: isFuture)
                  .id(index)
              }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
          }
          .frame(maxHeight: 380)
          .onAppear {
            proxy.scrollTo(editorState.history.currentIndex, anchor: .center)
          }
        }
      }
    }
    .padding(.vertical, 8)
    .frame(width: 400)
    .popoverContainerStyle()
  }

  private func historyRow(
    entry: HistoryEntry,
    index: Int,
    isCurrent: Bool,
    isFuture: Bool
  )
    -> some View
  {
    let entries = editorState.history.entries
    let diffs: [String] =
      index > 0
      ? History.describeChanges(from: entries[index - 1].snapshot, to: entry.snapshot) : []

    return Button {
      editorState.jumpToHistory(index: index)
    } label: {
      HStack(spacing: 8) {
        Circle()
          .fill(isCurrent ? ReframedColors.primaryText : ReframedColors.border)
          .frame(width: 6, height: 6)

        VStack(alignment: .leading, spacing: 2) {
          if index == 0 {
            Text("Initial state")
              .font(.system(size: FontSize.xs, weight: isCurrent ? .semibold : .regular))
              .foregroundStyle(
                isFuture
                  ? ReframedColors.tertiaryText
                  : isCurrent ? ReframedColors.primaryText : ReframedColors.secondaryText
              )
          } else {
            Text(diffs.first ?? "Editor settings updated")
              .font(.system(size: FontSize.xs, weight: isCurrent ? .semibold : .regular))
              .foregroundStyle(
                isFuture
                  ? ReframedColors.tertiaryText
                  : isCurrent ? ReframedColors.primaryText : ReframedColors.secondaryText
              )
              .lineLimit(1)
          }

          if diffs.count > 1 {
            Text(diffs.dropFirst().prefix(3).joined(separator: ", "))
              .font(.system(size: FontSize.xs))
              .foregroundStyle(ReframedColors.tertiaryText)
              .lineLimit(1)
          }
        }

        Spacer()

        Text(formatRelativeTime(entry.timestamp))
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.tertiaryText)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: Radius.md)
          .fill(isCurrent ? ReframedColors.selectedBackground : Color.clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(isFuture ? 0.6 : 1)
  }

}
