//
//  Substitutions.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation

enum Substitutions: Int, CaseIterable {
    case firstName, fullName
    
    var literal: String {
        switch self {
        case .fullName:
            return "<student full name>"
        case .firstName:
            return "<student first name>"
        }
    }
    
    var explanation: String {
        switch self {
        case .fullName:
            return "Insert student's full name"
        case .firstName:
            return "Insert student's first name"
        }
    }
}
