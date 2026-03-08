import SwiftUI

private let bundle = Bundle.module

struct DirectoryImportSummaryView: View {
    let result: DirectoryImportResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            headerView

            if !result.failedImports.isEmpty {
                failedSection
            }

            if !result.skippedFiles.isEmpty {
                skippedSection
            }

            Button(NSLocalizedString("import.directory.done", bundle: bundle, comment: "")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(minWidth: 560, minHeight: 300)
        .padding()
    }

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 4) {
            let summary = String(
                format: NSLocalizedString("import.directory.summary", bundle: bundle, comment: ""),
                result.importedCount, result.skippedFiles.count
            )
            Text(summary)
                .font(.headline)

            if !result.failedImports.isEmpty {
                let failed = String(
                    format: NSLocalizedString("import.directory.summary.failed", bundle: bundle, comment: ""),
                    result.failedImports.count
                )
                Text(failed)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding(.top)
    }

    @ViewBuilder
    private var failedSection: some View {
        Section {
            Table(result.failedImports) {
                TableColumn(NSLocalizedString("import.directory.column.filename", bundle: bundle, comment: ""),
                            value: \.filename)
                TableColumn(NSLocalizedString("import.directory.column.reason", bundle: bundle, comment: ""),
                            value: \.reason)
            }
            .frame(minHeight: 100)
        } header: {
            Text(NSLocalizedString("import.directory.failed_section", bundle: bundle, comment: ""))
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var skippedSection: some View {
        Section {
            Table(result.skippedFiles) {
                TableColumn(NSLocalizedString("import.directory.column.filename", bundle: bundle, comment: ""),
                            value: \.filename)
                TableColumn(NSLocalizedString("import.directory.column.format", bundle: bundle, comment: ""),
                            value: \.fileExtension)
                TableColumn(NSLocalizedString("import.directory.column.path", bundle: bundle, comment: ""),
                            value: \.path)
            }
            .frame(minHeight: 100)
        } header: {
            Text(NSLocalizedString("import.directory.skipped_section", bundle: bundle, comment: ""))
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
