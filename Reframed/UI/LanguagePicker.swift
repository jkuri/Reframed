import SwiftUI

struct LanguagePicker: View {
  @Binding var selection: CaptionLanguage
  var onSelect: (() -> Void)? = nil

  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool

  private var filteredLanguages: [CaptionLanguage] {
    if searchText.isEmpty { return CaptionLanguage.sortedCases }
    let query = searchText.lowercased()
    return CaptionLanguage.sortedCases.filter {
      $0.label.lowercased().hasPrefix(query)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
        TextField("Search…", text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 12))
          .focused($isSearchFocused)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 7)

      Divider()
        .background(ReframedColors.border)

      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 2) {
            ForEach(filteredLanguages) { lang in
              Button {
                selection = lang
                onSelect?()
              } label: {
                HStack {
                  Text(lang.label)
                    .font(.system(size: 12))
                  Spacer()
                  if selection == lang {
                    Image(systemName: "checkmark")
                      .font(.system(size: 10, weight: .semibold))
                  }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .id(lang)
            }
          }
          .padding(4)
        }
        .onAppear {
          isSearchFocused = true
          proxy.scrollTo(selection, anchor: .center)
        }
      }
    }
    .frame(width: 220, height: 300)
  }
}
