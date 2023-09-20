//
//  MessageFilter.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation

enum MessageFilter: CaseIterable, Identifiable {
    case notSubmitted, notGraded, scoredMoreThan, scoredLessThan, markedIncomplete, reassigned
    
    var id: Self {
        return self
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
    var title: String {
        switch self {
        case .notSubmitted:
            return "Have not yet submitted"
        case .notGraded:
            return "Have not been graded"
        case .scoredMoreThan:
            return "Scored more than"
        case .scoredLessThan:
            return "Scored less than"
        case .markedIncomplete:
            return "Marked incomplete"
        case .reassigned:
            return "Reassigned"
        }
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L215
    func subject(assignmentName: String, score: Double) -> String {
        switch self {
        case .notSubmitted:
            return "No submission for \(assignmentName)"
        case .notGraded:
            return "No grade for \(assignmentName)"
        case .scoredMoreThan:
            return "Scored more than \(score.formatted()) on \(assignmentName)"
        case .scoredLessThan:
            return "Scored less than \(score.formatted()) on \(assignmentName)"
        case .markedIncomplete:
            return "\(assignmentName) is incomplete"
        case .reassigned:
            return "\(assignmentName) is reassigned"
        }
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
    var scoreNeeded: Bool {
        switch self {
        case .scoredLessThan, .scoredMoreThan:
            return true
        default:
            return false
        }
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
    func shouldShow(_ assignment: Assignment) -> Bool {
        switch self {
        case .notSubmitted:
            let disallowedSubmissionTypes: Set<String> = ["on_paper", "none", "not_graded", ""];
            return !disallowedSubmissionTypes.contains(assignment.submissionTypes[0])
        case .notGraded:
            return true
        case .scoredMoreThan, .scoredLessThan:
            let scoredRequiredGradingTypes: Set<String> = ["points", "percent", "letter_grade", "gpa_scale"]
            let isScored = scoredRequiredGradingTypes.contains(assignment.gradingType)
            return isScored
        case .markedIncomplete:
            return assignment.gradingType == "pass_fail"
        case .reassigned:
            // This is a bug in MessageStudentsWhoDialog.tsx that we will reproduce here for consistency with the web UI.
            // I think that code is intending to test against multiple types but actually due to the use of || just tests the first.
            let disallowedSubmissionTypes: Set<String> = ["on_paper"/*, "external_tool", "none", "discussion_topic", "online_quiz"*/]
            let isReassignable = (assignment.allowedAttempts == -1 || (assignment.allowedAttempts > 1)) &&
            assignment.dueAt != nil &&
            Set(assignment.submissionTypes).intersection(disallowedSubmissionTypes).isEmpty
            
            return isReassignable
        }
    }
    
    static func applicableFilters(assignment: Assignment?) -> [Self] {
        if let assignment {
            return Self.allCases.filter({ $0.shouldShow(assignment) })
        } else {
            return []
        }
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L176
    func filterStudents(_ studentAssignmentInfos: [StudentAssignmentInfo], score: Double) -> [StudentAssignmentInfo] {
        switch self {
        case .notSubmitted:
            return studentAssignmentInfos.filter({ $0.submittedAt == nil })
        case .notGraded:
            return studentAssignmentInfos.filter({ $0.grade == nil })
        case .scoredMoreThan:
            return studentAssignmentInfos.filter { student in
                if let studentScore = student.score {
                    return studentScore > score
                }
                
                return false
            }
        case .scoredLessThan:
            return studentAssignmentInfos.filter { student in
                if let studentScore = student.score {
                    return studentScore < score
                }
                
                return false
            }
        case .markedIncomplete:
            return studentAssignmentInfos.filter({ $0.grade == "incomplete" })
        case .reassigned:
            return studentAssignmentInfos.filter({ $0.redoRequest })
        }
    }
}
