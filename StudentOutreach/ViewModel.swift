//
//  ViewModel.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation

class ViewModel: ObservableObject {
    @Published var accessToken = "" {
        didSet {
            Task { @MainActor in
                courses = await fetchCourses()
            }
        }
    }
    
    @Published var courses: [Course] = []
    @Published var selectedCourse: Course? = nil {
        didSet {
            Task { @MainActor in
                if messageMode == .assignment {
                    assignments = await fetchAssignments()
                } else {
                    studentAssignmentInfos = await fetchAllStudentAssignmentInfos()
                }
            }
        }
    }
    
    @Published var assignments: [Assignment] = []
    @Published var selectedAssignment: Assignment? = nil {
        didSet {
            Task { @MainActor in
                studentAssignmentInfos = await fetchStudentAssignmentInfos()
            }
            
            generateSubject()
        }
    }
    @Published var studentAssignmentInfos: [StudentAssignmentInfo] = [] {
        didSet {
            disabledStudentIds.removeAll()
        }
    }
    
    @Published var messageFilter: MessageFilter = .notSubmitted {
        didSet {
            generateSubject()
            disabledStudentIds.removeAll()
        }
    }
    @Published var messageFilterScore: Double = 0 {
        didSet {
            generateSubject()
            disabledStudentIds.removeAll()
        }
    }
    @Published var messageMode: MessageMode = .assignment {
        didSet {
            Task { @MainActor in
                if messageMode == .assignment {
                    assignments = await fetchAssignments()
                } else {
                    studentAssignmentInfos = await fetchAllStudentAssignmentInfos()
                }
            }
        }
    }
    
    @Published var searchTerm: String = ""
    
    @Published var subject = ""
    @Published var message = ""
    
    @Published var disabledStudentIds: Set<Int> = []
    
    var studentsToMessage: [StudentAssignmentInfo] {
        return studentsMatchingFilter.filter({ !disabledStudentIds.contains($0.id) })
    }
    
    var substitutionsUsed: Int {
        var count = 0
        for substitution in Substitutions.allCases {
            let comps = message.components(separatedBy: substitution.literal)
            count += comps.count - 1
        }
        
        return count
    }
    
    func finalMessageBody(fullName: String, firstName: String) -> String {
        var message = self.message
        message = message.replacingOccurrences(of: Substitutions.firstName.literal, with: firstName)
        message = message.replacingOccurrences(of: Substitutions.fullName.literal, with: fullName)
        return message
    }
    
    var studentsMatchingFilter: [StudentAssignmentInfo] {
        var results = [StudentAssignmentInfo]()
        
        if self.messageMode == .assignment {
            results.append(contentsOf: messageFilter.filterStudents(studentAssignmentInfos, score: messageFilterScore))
        } else {
            results.append(contentsOf: studentAssignmentInfos)
        }
        
        return results
    }
    
    func fetchCourses() async -> [Course] {
        var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses?include=term&per_page=100")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let courses = try decoder.decode([Course].self, from: data)
            return courses.sorted { first, second in
                let firstString = (first.courseCode ?? "") + first.name + (first.term.isDefaultTerm ? "" : first.term.name)
                let secondString = (second.courseCode ?? "") + second.name + (second.term.isDefaultTerm ? "" : second.term.name)
                return firstString < secondString
            }
        } catch {
            return []
        }
    }
    
    func fetchAssignments() async -> [Assignment] {
        guard let course = selectedCourse else {
            return []
        }
        
        var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignments?per_page=100")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let assignments = try decoder.decode([Assignment].self, from: data)
            return assignments.sorted(by: { $0.name < $1.name })
        } catch {
            print("Hit error fetching assignments: \(error)")
            return []
        }
    }
    
    func fetchAllStudentAssignmentInfos() async -> [StudentAssignmentInfo] {
        guard let course = selectedCourse else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            // Grab all students in this course (but not the test user).
            let userRequest = {
                var userRequest = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/users?enrollment_type=student&per_page=100")!)
                userRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                return userRequest
            }()
            let (userData, _) = try await URLSession.shared.data(for: userRequest)
            let users = try decoder.decode([User].self, from: userData)

            var infos = [StudentAssignmentInfo]()
            for user in users {
                infos.append(StudentAssignmentInfo(id: user.id, name: user.name, score: nil, submitted: false))
            }
            
            return infos
        } catch {
            print("Hit error fetching all studentAssignmentInfos: \(error)")
            return []
        }
    }
    
    func fetchStudentAssignmentInfos() async -> [StudentAssignmentInfo] {
        guard let assignment = selectedAssignment, let course = selectedCourse else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            // Grab all students eligible to submit the assignment.
            let gradeableStudentRequest = {
                var gradeableStudentRequest = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignments/\(assignment.id)/gradeable_students?per_page=100")!)
                gradeableStudentRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                return gradeableStudentRequest
            }()
            async let (gradeableStudentData, _) = try URLSession.shared.data(for: gradeableStudentRequest)
            
            // Grab all submissions to the assignment.
            let submissionRequest = {
                var submissionRequest = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignments/\(assignment.id)/submissions?per_page=100")!)
                submissionRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                return submissionRequest
            }()
            async let (submissionData, _) = try URLSession.shared.data(for: submissionRequest)
            
            // Grab all students in this course (but not the test user).
            let userRequest = {
                var userRequest = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/users?enrollment_type=student&per_page=100")!)
                userRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                return userRequest
            }()
            async let (userData, _) = try URLSession.shared.data(for: userRequest)
            
            let displayStudents = try await decoder.decode([UserDisplay].self, from: gradeableStudentData)
            let submissions = try await decoder.decode([Submission].self, from: submissionData)
            let users = try await decoder.decode([User].self, from: userData)

            var infos = [StudentAssignmentInfo]()
            for displayStudent in displayStudents {
                let user = users.first(where: { $0.id == displayStudent.id })
                if let user {
                    let submission = submissions.first(where: { $0.userId == displayStudent.id })
                    infos.append(StudentAssignmentInfo(id: user.id, name: displayStudent.displayName, score: submission?.score, submitted: submission?.submittedAt != nil))
                }
            }
            
            return infos
        } catch {
            print("Hit error fetching studentAssignmentInfos: \(error)")
            return []
        }
    }
    
    func generateSubject() {
        if let selectedAssignment {
            subject = messageFilter.subject(assignmentName: selectedAssignment.name, score: messageFilterScore)
        } else {
            subject = ""
        }
    }
          
    @Published var sendingMessage = false
    
    func sendMessage() async {
        guard let selectedCourse else {
            return
        }
        
        sendingMessage = true
        
        let recipients = studentsToMessage
        let subject = subject
        let contextCode = "course_\(selectedCourse.id)"
        for recipient in recipients {
            let body = finalMessageBody(fullName: recipient.name, firstName: recipient.firstName)
            
            var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type");
            if let data: Data = "recipients=\(recipient.id)&subject=\(subject)&body=\(body)&context_code=\(contextCode)&mode=async&group_conversation=true&bulk_message=true".data(using: .utf8) {
                request.httpBody = data
                
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode != 202 {
                            print("Error sending message: \(response)")
                        }
                    }
                } catch {
                    print("Hit error posting new conversation: \(error)")
                }
            }
        }
        
        sendingMessage = false
    }
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
}

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
            return "Scored more than \(score) on \(assignmentName)"
        case .scoredLessThan:
            return "Scored less than \(score) on \(assignmentName)"
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
            return disallowedSubmissionTypes.contains(assignment.submissionTypes[0])
        case .notGraded:
            return true
        case .scoredMoreThan, .scoredLessThan:
            let scoredRequiredGradingTypes: Set<String> = ["points", "percent", "letter_grade", "gpa_scale"]
            let isScored = scoredRequiredGradingTypes.contains(assignment.gradingType)
            return isScored
        case .markedIncomplete:
            return assignment.gradingType == "pass_fail"
        case .reassigned:
            let disallowedSubmissionTypes: Set<String> = ["on_paper", "external_tool", "none", "discussion_topic", "online_quiz"]
            let isReassignable = (assignment.allowedAttempts == -1 || (assignment.allowedAttempts > 1)) &&
            assignment.dueAt != nil &&
            Set(assignment.submissionTypes).intersection(disallowedSubmissionTypes).isEmpty
            
            return isReassignable
        }
    }
    
    func applicableFilters(assignment: Assignment) -> [Self] {
        return Self.allCases.filter({ $0.shouldShow(assignment) })
    }
    
    // See https://github.com/instructure/canvas-lms/blob/c06e6f6b99467d601198ac4f5dd6558071a5cd3c/ui/shared/message-students-dialog/react/MessageStudentsWhoDialog.tsx#L176
    // TODO: Implement
    func filterStudents(_ studentAssignmentInfos: [StudentAssignmentInfo], score: Double) -> [StudentAssignmentInfo] {
        switch self {
        case .notSubmitted:
            return studentAssignmentInfos.filter({ !$0.submitted })
        case .notGraded:
            return studentAssignmentInfos.filter({ $0.score == nil })
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
            fallthrough
        case .reassigned:
            return studentAssignmentInfos
        }
    }
}

struct StudentAssignmentInfo: Hashable {
    let id: Int
    let name: String
    let score: Double?
    let submitted: Bool
    
    var firstName: String {
        let formatter = PersonNameComponentsFormatter()
        let comps = formatter.personNameComponents(from: name)
        return comps?.givenName ?? name
    }
}

struct UserDisplay: Decodable, Identifiable, Hashable {
    let id: Int
    let displayName: String
}

struct User: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct Submission: Decodable, Hashable {
    let userId: Int
    let score: Double?
    let submittedAt: Date?
}

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

enum MessageMode: Int, Hashable, CaseIterable {
    case `assignment`, general
    
    var title: String {
        switch self {
        case .assignment:
            return "Based on assignment"
        case .general:
            return "Any students"
        }
    }
}
