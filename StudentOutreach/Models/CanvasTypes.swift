//
//  CanvasTypes.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation

// MARK: - UserDisplay

struct UserDisplay: Decodable, Identifiable, Hashable {
  let id: Int
  let displayName: String
}

// MARK: - User

struct User: Decodable, Identifiable, Hashable {
  let id: Int
  let name: String
  let sortableName: String
  let enrollments: [Enrollment]
}

// MARK: - Submission

struct Submission: Decodable, Hashable {
  let userId: Int
  let score: Double?
  let submittedAt: Date?
  let grade: String?
  let redoRequest: Bool
}

// MARK: - Enrollment

struct Enrollment: Decodable, Identifiable, Hashable {
  let id: Int
  let grades: Grades
  let lastActivityAt: Date?
}

// MARK: - Grades

struct Grades: Decodable, Hashable {
  let currentScore: Double?
}

// MARK: - Course

struct Course: Decodable, Identifiable, Hashable {
  let id: Int
  let name: String
  let courseCode: String?
  let term: Term
  let workflowState: String
  let sections: [Section]
}

// MARK: - Section

struct Section: Decodable, Identifiable, Hashable {
  let id: Int
  let name: String
}

// MARK: - Term

struct Term: Decodable, Identifiable, Hashable {
  let id: Int
  let name: String

  var isDefaultTerm: Bool {
    name == "Default Term"
  }
}

// MARK: - Assignment

struct Assignment: Decodable, Identifiable, Hashable {
  let id: Int
  let name: String
  let submissionTypes: [String]
  let allowedAttempts: Int
  let gradingType: String
  let dueAt: Date?
  let published: Bool
}

// MARK: - AssignmentGroup

struct AssignmentGroup: Decodable, Identifiable, Hashable {
  let id: Int
  let assignments: [Assignment]
}

// MARK: - PostMessageData

struct PostMessageData: Encodable {
  let recipients: [String]
  let subject: String
  let body: String
  let contextCode: String
  let mode = "async"
  let groupConversation = true
  let bulkMessage = true
}
