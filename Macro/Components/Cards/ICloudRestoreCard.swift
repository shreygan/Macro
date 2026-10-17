//
//  ICloudRestoreCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/17/26.
//

import SwiftUI

struct ICloudRestoreCard: View {
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    private var subtitle: String {
        if syncMonitor.isInitialRestorePaused {
            return String(localized: "Continues when iCloud is available")
        }
        guard let summary = CloudSyncMonitor.restoredSummary(
            logs: syncMonitor.restoredLogCount,
            entries: syncMonitor.restoredEntryCount
        ) else { return String(localized: "Downloading your data...") }
        return String(localized: "\(summary) so far")
    }

    var body: some View {
        Card {
            BaseRowLayout(
                icon: .customSymbol(
                    syncMonitor.isInitialRestorePaused ? "icloud.slash" : "icloud.and.arrow.down"
                ),
                title: syncMonitor.isInitialRestorePaused
                    ? String(localized: "Restore Paused")
                    : String(localized: "Restoring from iCloud"),
                subtitle: subtitle,
                animatesSubtitle: true
            ) {
                if !syncMonitor.isInitialRestorePaused {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }
            }
            .animation(.snappy, value: syncMonitor.isInitialRestorePaused)
        }
    }
}

#Preview {
    ICloudRestoreCard()
        .padding()
        .environment(CloudSyncMonitor())
}
