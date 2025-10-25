//
//  MessageMode.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation

enum MessageMode: Int, Hashable, CaseIterable {
  case `assignment`
  case course

  var title: String {
    switch self {
    case .assignment:
      "Based on assignment"
    case .course:
      "Based on course"
    }
  }
}
