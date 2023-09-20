//
//  CanvasTypes.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation

struct UserDisplay: Decodable, Identifiable, Hashable {
    let id: Int
    let displayName: String
}

struct User: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let sortableName: String
    let enrollments: [Enrollment]
}

struct Submission: Decodable, Hashable {
    let userId: Int
    let score: Double?
    let submittedAt: Date?
    let grade: String?
    let redoRequest: Bool
}

struct Enrollment: Decodable, Identifiable, Hashable {
    let id: Int
    let grades: Grades
}

struct Grades: Decodable, Hashable {
    let currentScore: Double
}

struct Course: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let courseCode: String?
    let term: Term
    let workflowState: String
}

struct Term: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    
    var isDefaultTerm: Bool {
        return name == "Default Term"
    }
}

struct Assignment: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let submissionTypes: [String]
    let allowedAttempts: Int
    let gradingType: String
    let dueAt: Date?
    let published: Bool
}

struct PostMessageData: Encodable {
    let recipients: [Int]
    let subject: String
    let body: String
    let contextCode: String
    let mode = "async"
    let groupConversation = true
    let bulkMessage = true
}
