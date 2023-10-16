//
//  MessageFilter.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation

enum MessageFilter: CaseIterable, Identifiable {
    case notSubmitted, notGraded, scoredMoreThan, scoredLessThan, markedIncomplete, reassigned
    case courseScoreLessThan, courseScoreMoreThan, courseScoreBetween, all
    
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
        case .courseScoreLessThan:
            return "Course score less than"
        case .courseScoreMoreThan:
            return "Course score more than"
        case .courseScoreBetween:
            return "Course score is between"
        case .all:
            return "All students in course"
        }
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L215
    func subject(assignmentName: String?, score: Double, score2: Double, courseName: String) -> String {
        switch self {
        case .notSubmitted:
            if let assignmentName {
                return "No submission for \(assignmentName)"
            }
        case .notGraded:
            if let assignmentName {
                return "No grade for \(assignmentName)"
            }
        case .scoredMoreThan:
            if let assignmentName {
                return "Scored more than \(score.formatted()) on \(assignmentName)"
            }
        case .scoredLessThan:
            if let assignmentName {
                return "Scored less than \(score.formatted()) on \(assignmentName)"
            }
        case .markedIncomplete:
            if let assignmentName {
                return "\(assignmentName) is incomplete"
            }
        case .reassigned:
            if let assignmentName {
                return "\(assignmentName) is reassigned"
            }
        case .courseScoreLessThan:
            return "Score in \(courseName) is less than \(score.formatted())"
        case .courseScoreMoreThan:
            return "Score in \(courseName) is more than \(score.formatted())"
        case .courseScoreBetween:
            return "Score in \(courseName) is more than \(score.formatted()) and less than \(score2.formatted())"
        case .all:
            return ""
        }
        
        return ""
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
    var scoreNeeded: Bool {
        switch self {
        case .scoredLessThan, .scoredMoreThan, .courseScoreLessThan, .courseScoreMoreThan, .courseScoreBetween:
            return true
        default:
            return false
        }
    }
    
    var score2Needed: Bool {
        switch self {
        case .courseScoreBetween:
            return true
        default:
            return false
        }
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
    func shouldShow(assignment: Assignment?, course: Course?, mode: MessageMode) -> Bool {
        switch self {
        case .notSubmitted:
            if let assignment, mode == .assignment {
                let disallowedSubmissionTypes: Set<String> = ["on_paper", "none", "not_graded", ""];
                return !disallowedSubmissionTypes.contains(assignment.submissionTypes[0])
            }
        case .notGraded:
            return assignment != nil && mode == .assignment
        case .scoredMoreThan, .scoredLessThan:
            if let assignment, mode == .assignment {
                let scoredRequiredGradingTypes: Set<String> = ["points", "percent", "letter_grade", "gpa_scale"]
                let isScored = scoredRequiredGradingTypes.contains(assignment.gradingType)
                return isScored
            }
        case .markedIncomplete:
            if let assignment, mode == .assignment {
                return assignment.gradingType == "pass_fail"
            }
        case .reassigned:
            if let assignment, mode == .assignment {
                // This is a bug in MessageStudentsWhoDialog.tsx that we will reproduce here for consistency with the web UI.
                // I think that code is intending to test against multiple types but actually due to the use of || just tests the first.
                let disallowedSubmissionTypes: Set<String> = ["on_paper"/*, "external_tool", "none", "discussion_topic", "online_quiz"*/]
                let isReassignable = (assignment.allowedAttempts == -1 || (assignment.allowedAttempts > 1)) &&
                assignment.dueAt != nil &&
                Set(assignment.submissionTypes).intersection(disallowedSubmissionTypes).isEmpty
                
                return isReassignable
            }
        case .courseScoreLessThan, .courseScoreMoreThan, .courseScoreBetween, .all:
            return course != nil && mode == .course
        }
        
        return false
    }
    
    static func applicableFilters(assignment: Assignment?, course: Course?, mode: MessageMode) -> [Self] {
        return Self.allCases.filter({ $0.shouldShow(assignment: assignment, course: course, mode: mode) })
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L176
    func filterStudents(_ studentAssignmentInfos: [StudentAssignmentInfo], score: Double, score2: Double) -> [StudentAssignmentInfo] {
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
        case .courseScoreLessThan:
            return studentAssignmentInfos.filter({ $0.courseScore < score })
        case .courseScoreMoreThan:
            return studentAssignmentInfos.filter({ $0.courseScore > score })
        case .courseScoreBetween:
            return studentAssignmentInfos.filter({ $0.courseScore > score && $0.courseScore < score2 })
        case .all:
            return studentAssignmentInfos
        }
    }
}
