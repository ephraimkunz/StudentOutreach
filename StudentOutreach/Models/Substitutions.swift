//
//  Substitutions.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation

enum Substitutions: Int, CaseIterable {
  case firstName
  case fullName

  var literal: String {
    switch self {
    case .fullName:
      "<student full name>"
    case .firstName:
      "<student first name>"
    }
  }

  var explanation: String {
    switch self {
    case .fullName:
      "Insert student's full name"
    case .firstName:
      "Insert student's first name"
    }
  }
}
