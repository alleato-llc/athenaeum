import SwiftUI
import Ligature

private let bundle = Bundle.module

struct HighlightPopoverView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @State private var showEraseAllConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { viewModel.isHighlightModeActive },
                set: { _ in viewModel.toggleHighlightMode() }
            )) {
                Label(NSLocalizedString("highlight.mode", bundle: bundle, comment: ""),
                      systemImage: "pencil")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("highlight.color", bundle: bundle, comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(HighlightColor.palette) { color in
                        let c = color.swiftUIColor
                        Circle()
                            .fill(Color(red: c.red, green: c.green, blue: c.blue, opacity: c.opacity))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(viewModel.highlightColor.id == color.id
                                            ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                viewModel.setHighlightColor(color)
                            }
                            .help(NSLocalizedString(color.name, bundle: bundle, comment: ""))
                    }
                }
            }

            Divider()

            Toggle(isOn: Binding(
                get: { viewModel.isEraserModeActive },
                set: { _ in viewModel.toggleEraserMode() }
            )) {
                Label(NSLocalizedString("highlight.eraser", bundle: bundle, comment: ""),
                      systemImage: "eraser")
            }

            Button(role: .destructive) {
                showEraseAllConfirmation = true
            } label: {
                Label(NSLocalizedString("highlight.eraseAll", bundle: bundle, comment: ""),
                      systemImage: "trash")
            }
            .alert(NSLocalizedString("highlight.eraseAll.confirm", bundle: bundle, comment: ""),
                   isPresented: $showEraseAllConfirmation) {
                Button(NSLocalizedString("highlight.eraseAll.yes", bundle: bundle, comment: ""),
                       role: .destructive) {
                    viewModel.eraseAllHighlightsOnPage()
                }
                Button(NSLocalizedString("Cancel", bundle: bundle, comment: ""), role: .cancel) {}
            }
        }
        .padding()
        .frame(width: 220)
    }
}
