//
//  ImportFeedback.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftUI

struct ImportIssue: Identifiable, Equatable {
    enum Kind: Identifiable {
        case duplicate
        case repeated
        case invalid

        var id: Self { self }
    }

    let id = UUID()
    let kind: Kind
    let row: Int
    let name: String?
    let reason: String
}

struct DataTransferAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func selectionFailed(_ error: Error) -> DataTransferAlert {
        DataTransferAlert(
            title: "Couldn't Open File",
            message:
                "The file couldn't be selected. \(error.localizedDescription)"
        )
    }

    static let accessDenied = DataTransferAlert(
        title: "Couldn't Open File",
        message:
            "Macro doesn't have permission to read this file. Try moving it to the Files app and selecting it again."
    )

    static func unreadable(_ error: Error) -> DataTransferAlert {
        DataTransferAlert(
            title: "Couldn't Read File",
            message:
                "The file couldn't be read. \(error.localizedDescription)"
        )
    }

    static let unsupportedEncoding = DataTransferAlert(
        title: "Unsupported File",
        message:
            "This file's text encoding isn't supported. Save it as a UTF-8 CSV and try again."
    )

    static let emptyFile = DataTransferAlert(
        title: "Empty File",
        message: "This CSV file doesn't contain any rows."
    )

    static let noEntries = DataTransferAlert(
        title: "No Entries Found",
        message: "This CSV file only contains a header row."
    )

    static let unrecognizedFormat = DataTransferAlert(
        title: "Unrecognized Format",
        message:
            "The file's first row needs to name its columns, including at least Name and Calories."
    )

    static let missingDateColumn = DataTransferAlert(
        title: "No Date Column",
        message:
            "This looks like a log history file, but it has no Date column. Add a header named Date (or Timestamp) and try again."
    )

    static let invalidBackup = DataTransferAlert(
        title: "Not a Macro Backup",
        message:
            "This file isn't a Macro backup or it's damaged. Choose a .json file created with Export › Full Backup."
    )

    static let newerBackup = DataTransferAlert(
        title: "Update Required",
        message:
            "This backup was made with a newer version of Macro. Update the app to restore it."
    )

    static func saveFailed(_ error: Error) -> DataTransferAlert {
        DataTransferAlert(
            title: "Import Failed",
            message:
                "Your entries couldn't be saved, so nothing was imported. \(error.localizedDescription)"
        )
    }

    static func exportFailed(_ error: Error) -> DataTransferAlert {
        DataTransferAlert(
            title: "Export Failed",
            message:
                "The file couldn't be saved. \(error.localizedDescription)"
        )
    }
}

extension View {
    func dataTransferAlert(
        _ alert: Binding<DataTransferAlert?>,
        isEnabled: Bool = true
    ) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { isEnabled && alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { presented in
            Text(presented.message)
        }
    }
}
