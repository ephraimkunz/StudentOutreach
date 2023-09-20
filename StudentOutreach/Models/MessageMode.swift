//
//  MessageMode.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation

enum MessageMode: Int, Hashable, CaseIterable {
    case `assignment`, course
    
    var title: String {
        switch self {
        case .assignment:
            return "Based on assignment"
        case .course:
            return "Based on course"
        }
    }
}
