//
//  CSVCoder.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import Foundation

struct CSVRow {
    let number: Int
    let fields: [String]
}

protocol CSVColumn: CaseIterable, Hashable, RawRepresentable
where RawValue == String {
    var aliases: [String] { get }
    var aliasRequiresText: Bool { get }
}

extension CSVColumn {
    var aliasRequiresText: Bool { false }
}

enum CSVCoder {
    static func columns<Column: CSVColumn>(
        in header: [String],
        rows: [CSVRow] = [],
        as _: Column.Type
    ) -> [Column: Int] {
        let keys = header.map {
            $0.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: " ")
        }
        var columns: [Column: Int] = [:]
        var claimed = Set<Int>()

        for column in Column.allCases {
            let candidates = [column.rawValue.lowercased()] + column.aliases

            for (rank, candidate) in candidates.enumerated() {
                guard
                    let index = keys.indices.first(where: {
                        keys[$0] == candidate && !claimed.contains($0)
                    })
                else { continue }

                if rank > 0 && column.aliasRequiresText
                    && !containsText(rows, at: index)
                {
                    continue
                }

                columns[column] = index
                claimed.insert(index)
                break
            }
        }

        return columns
    }

    private static func containsText(_ rows: [CSVRow], at index: Int) -> Bool {
        guard !rows.isEmpty else { return true }
        return rows.contains { row in
            guard index < row.fields.count else { return false }
            let value = row.fields[index].trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return !value.isEmpty && Double(value) == nil
        }
    }

    private static let formulaTriggers: Set<Character> = [
        "=", "+", "-", "@", "\t", "\r",
    ]

    static func decode(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(3))

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data, encoding: .utf8)
        }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }

        if data.contains(0) {
            guard data.count > 1 else { return nil }
            let isLittleEndian = data[data.startIndex + 1] == 0
            return String(
                data: data,
                encoding: isLittleEndian ? .utf16LittleEndian : .utf16BigEndian
            )
        }

        let encodings: [String.Encoding] = [.utf8, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }

    static func parse(_ text: String) -> [CSVRow] {
        var rows: [CSVRow] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var rowNumber = 1
        var currentLine = 1

        let characters = Array(
            text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        )
        var index = 0

        func finishRow() {
            row.append(unprotect(field))
            if row.contains(where: {
                !$0.trimmingCharacters(in: .whitespaces).isEmpty
            }) {
                rows.append(CSVRow(number: rowNumber, fields: row))
            }
            row = []
            field = ""
        }

        while index < characters.count {
            let character = characters[index]

            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count
                        && characters[index + 1] == "\""
                    {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    if character.isNewline { currentLine += 1 }
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(unprotect(field))
                    field = ""
                case "\n", "\r\n", "\r":
                    finishRow()
                    currentLine += 1
                    rowNumber = currentLine
                default:
                    field.append(character)
                }
            }

            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return rows
    }

    static func escape(_ field: String) -> String {
        let protected = protect(field)
        let needsQuotes =
            protected.contains { $0 == "," || $0 == "\"" || $0.isNewline }
            || protected.first?.isWhitespace == true
            || protected.last?.isWhitespace == true

        guard needsQuotes else { return protected }
        return "\""
            + protected.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func encode(_ rows: [[String]]) -> String {
        rows
            .map { row in row.map { escape($0) }.joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    private static func startsWithFormula(_ field: Substring) -> Bool {
        guard let first = field.first else { return false }
        return formulaTriggers.contains(first)
    }

    private static func protect(_ field: String) -> String {
        guard Double(field) == nil,
            startsWithFormula(field.drop(while: { $0 == "'" }))
        else { return field }
        return "'" + field
    }

    private static func unprotect(_ field: String) -> String {
        guard field.hasPrefix("'"),
            startsWithFormula(field.drop(while: { $0 == "'" }))
        else { return field }
        return String(field.dropFirst())
    }
}
