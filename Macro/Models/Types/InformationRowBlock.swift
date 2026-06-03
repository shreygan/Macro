//
//  InformationRowBlock.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/30/26.
//

enum InformationRowBlock: Hashable {
    case title(String)
    case text(String)
    case code(String)
    case bullets([String])
}
