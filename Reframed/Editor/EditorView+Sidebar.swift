import SwiftUI

extension EditorView {
  var editorSidebar: some View {
    VStack(spacing: 0) {
      HoverEffectScope {
        VStack(spacing: 2) {
          ForEach(EditorTab.availableCases) { tab in
            let disabled =
              (tab == .camera && !editorState.hasWebcam)
              || (tab == .audio && !editorState.hasSystemAudio && !editorState.hasMicAudio && editorState.cursorMetadataProvider == nil)
              || (tab == .cursor && editorState.cursorMetadataProvider == nil)
              || (tab == .zoom && editorState.cursorMetadataProvider == nil)
              || (tab == .captions && !editorState.hasMicAudio && !editorState.hasSystemAudio)
            Button {
              selectedTab = tab
            } label: {
              VStack(spacing: 3) {
                Image(systemName: tab.icon)
                  .font(.system(size: FontSize.base))
                  .foregroundStyle(ReframedColors.primaryText)
                Text(LocalizedStringKey(tab.label))
                  .font(.system(size: FontSize.xxs, weight: .semibold))
                  .foregroundStyle(selectedTab == tab ? ReframedColors.primaryText : ReframedColors.secondaryText)
              }
              .frame(width: 56, height: 48)
              .background(
                selectedTab == tab ? ReframedColors.muted : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.lg)
              )
              .contentShape(Rectangle())
              .opacity(disabled ? 0.45 : 1)
            }
            .buttonStyle(PlainCustomButtonStyle())
            .hoverEffect(id: "tab.\(tab.rawValue)")
            .disabled(disabled)
          }
        }
      }
      Spacer()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
  }
}
