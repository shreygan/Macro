//
//  LogSaveOption.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/28/26.
//

enum LogSaveOption: String, CaseIterable, Identifiable {
    case logOnly = "Log Only"
    case updateOriginal = "Log & Update"
    case saveAsNew = "Log & Save New"
    var id: Self { self }
}
