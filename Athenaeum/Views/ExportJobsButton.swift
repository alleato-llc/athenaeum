import SwiftUI

#if SWIFT_PACKAGE
private let bundle = Bundle.module
#else
private let bundle = Bundle.main
#endif

struct ExportJobsButton: View {
    @ObservedObject var jobManager: ExportJobManager

    @State private var showPopover = false

    var body: some View {
        if !jobManager.jobs.isEmpty {
            Button(action: { showPopover.toggle() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: jobManager.hasActiveJobs ? "arrow.down.doc.fill" : "arrow.down.doc")
                        .font(.system(size: 14))

                    if jobManager.hasActiveJobs {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("export.jobs.tooltip", bundle: bundle, comment: ""))
            .popover(isPresented: $showPopover, arrowEdge: .top) {
                ExportJobsPopover(jobManager: jobManager)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(.bar)
            .cornerRadius(8)
        }
    }
}

private struct ExportJobsPopover: View {
    @ObservedObject var jobManager: ExportJobManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(NSLocalizedString("export.jobs.title", bundle: bundle, comment: ""))
                    .font(.headline)
                Spacer()
                if jobManager.jobs.contains(where: { !$0.isActive }) {
                    Button(NSLocalizedString("export.jobs.clear", bundle: bundle, comment: "")) {
                        jobManager.clearCompleted()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(jobManager.jobs) { job in
                        ExportJobRow(job: job) {
                            jobManager.cancelJob(id: job.id)
                        } onRemove: {
                            jobManager.removeJob(id: job.id)
                        }
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 300)
    }
}

private struct ExportJobRow: View {
    let job: ExportJob
    let onCancel: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.bookTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                jobAction
            }

            HStack(spacing: 6) {
                statusIcon
                statusText
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if case .exporting(let current, let total) = job.status, total > 0 {
                ProgressView(value: Double(current), total: Double(total))
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .exporting:
            ProgressView()
                .controlSize(.mini)
        case .saving:
            ProgressView()
                .controlSize(.mini)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch job.status {
        case .pending:
            Text(NSLocalizedString("export.status.pending", bundle: bundle, comment: ""))
        case .exporting(let current, let total):
            Text(String(format: NSLocalizedString("export.progress.chapter", bundle: bundle, comment: ""),
                        current, total))
        case .saving:
            Text(NSLocalizedString("export.status.saving", bundle: bundle, comment: ""))
        case .completed:
            Text(NSLocalizedString("export.status.completed", bundle: bundle, comment: ""))
        case .failed(let message):
            Text(message)
                .foregroundColor(.red)
        case .cancelled:
            Text(NSLocalizedString("export.status.cancelled", bundle: bundle, comment: ""))
        }
    }

    @ViewBuilder
    private var jobAction: some View {
        if job.isActive {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("export.cancel", bundle: bundle, comment: ""))
        } else {
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }
}
