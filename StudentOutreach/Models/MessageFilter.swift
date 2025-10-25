//
//  MessageFilter.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation

enum MessageFilter: CaseIterable, Identifiable {
  case notSubmitted
  case notGraded
  case scoredMoreThan
  case scoredLessThan
  case markedIncomplete
  case reassigned
  case courseScoreLessThan
  case courseScoreMoreThan
  case courseScoreBetween
  case courseScoreEmpty
  case noCourseActivitySevenDays
  case all

  // MARK: Internal

  var id: Self {
    self
  }

  /// See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
  var title: String {
    switch self {
    case .notSubmitted:
      "Have not yet submitted"
    case .notGraded:
      "Have not been graded"
    case .scoredMoreThan:
      "Scored more than"
    case .scoredLessThan:
      "Scored less than"
    case .markedIncomplete:
      "Marked incomplete"
    case .reassigned:
      "Reassigned"
    case .courseScoreLessThan:
      "Course score less than"
    case .courseScoreMoreThan:
      "Course score more than"
    case .courseScoreBetween:
      "Course score is between"
    case .courseScoreEmpty:
      "Course score is empty"
    case .noCourseActivitySevenDays:
      "No course participation (7 days)"
    case .all:
      "All students in course"
    }
  }

  /// See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
  var scoreNeeded: Bool {
    switch self {
    case .scoredLessThan, .scoredMoreThan, .courseScoreLessThan, .courseScoreMoreThan, .courseScoreBetween:
      true
    default:
      false
    }
  }

  var score2Needed: Bool {
    switch self {
    case .courseScoreBetween:
      true
    default:
      false
    }
  }

  static func applicableFilters(assignment: Assignment?, course: Course?, mode: MessageMode) -> [Self] {
    Self.allCases.filter { $0.shouldShow(assignment: assignment, course: course, mode: mode) }
  }

  /// See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L215
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

    case .courseScoreEmpty:
      return ""

    case .noCourseActivitySevenDays:
      return "\(courseName) Participation"

    case .all:
      return ""
    }

    return ""
  }

  /// See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L132
  func shouldShow(assignment: Assignment?, course: Course?, mode: MessageMode) -> Bool {
    switch self {
    case .notSubmitted:
      if let assignment, mode == .assignment {
        let disallowedSubmissionTypes: Set<String> = ["on_paper", "none", "not_graded", ""]
        return !disallowedSubmissionTypes.contains(assignment.submissionTypes[0])
      }

    case .notGraded:
      return assignment != nil && mode == .assignment

    case .scoredMoreThan, .scoredLessThan:
      if let assignment, mode == .assignment {
        let scoredRequiredGradingTypes: Set<String> = ["points", "percent", "letter_grade", "gpa_scale"]
        return scoredRequiredGradingTypes.contains(assignment.gradingType)
      }

    case .markedIncomplete:
      if let assignment, mode == .assignment {
        return assignment.gradingType == "pass_fail"
      }

    case .reassigned:
      if let assignment, mode == .assignment {
        // This is a bug in MessageStudentsWhoDialog.tsx that we will reproduce here for consistency with the web UI.
        // I think that code is intending to test against multiple types but actually due to the use of || just tests the first.
        let disallowedSubmissionTypes: Set<String> =
          ["on_paper" /* , "external_tool", "none", "discussion_topic", "online_quiz" */ ]
        return (assignment.allowedAttempts == -1 || (assignment.allowedAttempts > 1)) &&
          assignment.dueAt != nil &&
          Set(assignment.submissionTypes).intersection(disallowedSubmissionTypes).isEmpty
      }

    case .courseScoreLessThan, .courseScoreMoreThan, .courseScoreBetween, .courseScoreEmpty, .noCourseActivitySevenDays, .all:
      return course != nil && mode == .course
    }

    return false
  }

  /// See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L176
  func filterStudents(
    _ studentAssignmentInfos: [StudentAssignmentInfo],
    score: Double,
    score2: Double,
  ) -> [StudentAssignmentInfo] {
    switch self {
    case .notSubmitted:
      studentAssignmentInfos.filter { $0.submittedAt == nil }

    case .notGraded:
      studentAssignmentInfos.filter { $0.grade == nil }

    case .scoredMoreThan:
      studentAssignmentInfos.filter { student in
        if let studentScore = student.score {
          return studentScore > score && student.submittedAt != nil
        }

        return false
      }

    case .scoredLessThan:
      studentAssignmentInfos.filter { student in
        if let studentScore = student.score {
          return studentScore < score && student.submittedAt != nil
        }

        return false
      }

    case .markedIncomplete:
      studentAssignmentInfos.filter { $0.grade == "incomplete" }

    case .reassigned:
      studentAssignmentInfos.filter { $0.redoRequest }

    case .courseScoreLessThan:
      studentAssignmentInfos.filter { sai in
        if let courseScore = sai.courseScore {
          courseScore < score
        } else {
          false
        }
      }

    case .courseScoreMoreThan:
      studentAssignmentInfos.filter { sai in
        if let courseScore = sai.courseScore {
          courseScore > score
        } else {
          false
        }
      }

    case .courseScoreBetween:
      studentAssignmentInfos.filter { sai in
        if let courseScore = sai.courseScore {
          courseScore > score && courseScore < score2
        } else {
          false
        }
      }

    case .courseScoreEmpty:
      studentAssignmentInfos.filter { $0.courseScore == nil }

    case .noCourseActivitySevenDays:
      studentAssignmentInfos.filter {
        guard let lastActivity = $0.lastCourseActivityAt else {
          // If lastCourseActivityAt is nil, include it in the filter.
          return true
        }
        // Check if the difference between lastActivity and the current date is more than 7 days.
        return lastActivity.distance(to: Date()) > 604800
      }

    case .all:
      studentAssignmentInfos
    }
  }
}
