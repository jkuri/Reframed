import AppKit
import SwiftUI

extension PropertiesPanel {
  var backgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "paintbrush.fill", title: "Background")

      SegmentPicker(
        items: BackgroundMode.allCases,
        label: { $0.label },
        selection: $backgroundMode
      )

      switch backgroundMode {
      case .color:
        solidColorGrid
      case .gradient:
        gradientGrid
      case .image:
        imageBackgroundSection
      }
    }
  }

  private var swatchColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
  }

  var gradientGrid: some View {
    LazyVGrid(columns: swatchColumns, spacing: 6) {
      ForEach(GradientPresets.all) { preset in
        SwatchButton(
          fill: LinearGradient(
            colors: preset.colors,
            startPoint: preset.startPoint,
            endPoint: preset.endPoint
          ),
          isSelected: selectedGradientId == preset.id
        ) {
          selectedGradientId = preset.id
        }
      }
    }
  }

  var imageBackgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      ImageDropSection(
        image: editorState.backgroundImage,
        onPick: { pickBackgroundImage() },
        onDrop: { url in
          editorState.setBackgroundImage(from: url)
          if case .image(let f) = editorState.backgroundStyle {
            backgroundImageFilename = f
          }
        }
      )
      if editorState.backgroundImage != nil {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
          SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fill Mode")

          SegmentPicker(
            items: BackgroundImageFillMode.allCases,
            label: { $0.label },
            selection: $editorState.backgroundImageFillMode
          )
        }
      }
    }
  }

  var solidColorGrid: some View {
    LazyVGrid(columns: swatchColumns, spacing: 6) {
      ForEach(TailwindColors.all) { preset in
        SwatchButton(
          fill: preset.swiftUIColor,
          isSelected: selectedColorId == preset.id
        ) {
          selectedColorId = preset.id
        }
      }
    }
  }

  func syncBackgroundMode() {
    switch editorState.backgroundStyle {
    case .none:
      backgroundMode = .color
      selectedColorId = "Black"
      editorState.backgroundStyle = .solidColor(CodableColor(r: 0, g: 0, b: 0))
    case .gradient(let id):
      backgroundMode = .gradient
      selectedGradientId = id
    case .solidColor(let color):
      backgroundMode = .color
      if let preset = TailwindColors.all.first(where: { $0.color == color }) {
        selectedColorId = preset.id
      }
    case .image(let filename):
      backgroundMode = .image
      backgroundImageFilename = filename
    }
  }

  func updateBackgroundStyle(mode: BackgroundMode) {
    switch mode {
    case .gradient:
      editorState.backgroundStyle = .gradient(selectedGradientId)
    case .color:
      if let id = selectedColorId, let preset = TailwindColors.all.first(where: { $0.id == id }) {
        editorState.backgroundStyle = .solidColor(preset.color)
      } else {
        let first = TailwindColors.all[0]
        selectedColorId = first.id
        editorState.backgroundStyle = .solidColor(first.color)
      }
    case .image:
      if case .image = editorState.backgroundStyle {
        return
      }
      if let filename = backgroundImageFilename {
        editorState.backgroundStyle = .image(filename)
      }
    }
  }

  func pickBackgroundImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      DispatchQueue.main.async {
        self.editorState.setBackgroundImage(from: url)
        if case .image(let f) = self.editorState.backgroundStyle {
          self.backgroundImageFilename = f
        }
      }
    }
  }
}
