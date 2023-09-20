//
//  ViewModel.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.ephraimkunz.StudentOutreach", category: "viewModel")

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

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
    
    @Published var messageFilter: MessageFilter? = nil {
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
        
        if let messageFilter {
            results.append(contentsOf: messageFilter.filterStudents(studentAssignmentInfos, score: messageFilterScore))
        }
        
        return results
    }
    
    func fetchCourses() async -> [Course] {
        var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses?include[]=term&per_page=100")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
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
            
            let assignments = try decoder.decode([Assignment].self, from: data)
            return assignments.filter({ $0.published }).sorted(by: { $0.name < $1.name })
        } catch {
            logger.error("Hit error fetching assignments: \(error)")
            return []
        }
    }
    
    func fetchAllStudentAssignmentInfos() async -> [StudentAssignmentInfo] {
        guard let course = selectedCourse else {
            return []
        }
        
        do {
            // Grab all students in this course (but not the test user).
            let userRequest = {
                var userRequest = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/users?enrollment_type=student&include[]=enrollments&per_page=100")!)
                userRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                return userRequest
            }()
            let (userData, _) = try await URLSession.shared.data(for: userRequest)
            let users = try decoder.decode([User].self, from: userData)
            
            var infos = [StudentAssignmentInfo]()
            for user in users {
                infos.append(StudentAssignmentInfo(id: user.id, name: user.name, sortableName: user.sortableName, score: nil, grade: nil, submittedAt: nil, redoRequest: false, courseScore: user.enrollments[0].grades.currentScore))
            }
            
            return infos.sorted(by: { $0.sortableName < $1.sortableName })
        } catch {
            logger.error("Hit error fetching all studentAssignmentInfos: \(error)")
            return []
        }
    }
    
    func fetchStudentAssignmentInfos() async -> [StudentAssignmentInfo] {
        guard let assignment = selectedAssignment, let course = selectedCourse else {
            return []
        }
        
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
                    let assignmentInfo = StudentAssignmentInfo(id: user.id, name: user.name, sortableName: user.sortableName, score: submission?.score, grade: submission?.grade, submittedAt: submission?.submittedAt, redoRequest: submission?.redoRequest ?? false, courseScore: user.enrollments[0].grades.currentScore)
                    infos.append(assignmentInfo)
                }
            }
            
            return infos.sorted(by: { $0.sortableName < $1.sortableName })
        } catch {
            logger.error("Hit error fetching studentAssignmentInfos: \(error)")
            return []
        }
    }
    
    func generateSubject() {
        if let messageFilter {
            if let selectedCourse {
                subject = messageFilter.subject(assignmentName: selectedAssignment?.name, score: messageFilterScore, courseName: selectedCourse.name)
            }
        } else {
            subject = ""
        }
    }
    
    @Published var sendingMessage = false
    
    func sendMessage() async {
        guard let selectedCourse else {
            return
        }
        
        Task { @MainActor in
            sendingMessage = true
        }
        
        let recipients = studentsToMessage
        let subject = subject
        let contextCode = "course_\(selectedCourse.id)"
        
        if substitutionsUsed > 0 {
            for recipient in recipients {
                let body = finalMessageBody(fullName: recipient.name, firstName: recipient.firstName)
                
                var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.httpMethod = "POST"
                
                request.setValue("application/json", forHTTPHeaderField:"Content-Type");
                let postData = PostMessageData(recipients: [recipient.id], subject: subject, body: body, contextCode: contextCode)
                
                do {
                    let data = try encoder.encode(postData);
                    request.httpBody = data
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode != 202 {
                            logger.error("Error sending message: \(response)")
                        }
                    }
                } catch {
                    logger.error("Hit error posting new conversation: \(error)")
                }
            }
        } else {
            // No substitutions, so just send one bulk message (like the webUI does today).
            let body = finalMessageBody(fullName: "", firstName: "")
            
            var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            
            request.setValue("application/json", forHTTPHeaderField:"Content-Type");
            let postData = PostMessageData(recipients: recipients.map({ $0.id }), subject: subject, body: body, contextCode: contextCode)
            
            do {
                let data = try encoder.encode(postData);
                request.httpBody = data
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 202 {
                        logger.error("Error sending message: \(response)")
                    }
                }
            } catch {
                logger.error("Hit error posting new conversation: \(error)")
            }
        }
        
        Task { @MainActor in
            sendingMessage = false
        }
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
    let published: Bool
}

struct StudentAssignmentInfo: Hashable {
    let id: Int
    let name: String
    let sortableName: String
    let score: Double?
    let grade: String?
    let submittedAt: Date?
    let redoRequest: Bool
    
    let courseScore: Double
    
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

struct Enrollment: Decodable, Identifiable, Hashable {
    let id: Int
    let grades: Grades
}

struct Grades: Decodable, Hashable {
    let currentScore: Double
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
