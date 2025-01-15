//
//  Networking.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/20/23.
//

import Foundation
import os.log

struct Networking {
    let accessToken: String
    
    private let logger = Logger(subsystem: "com.ephraimkunz.StudentOutreach", category: "networking")
    
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
    
    func fetchCourses() async -> [Course] {
        var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses?enrollment_type=teacher&enrollment_state=active&include[]=term&include[]=sections&per_page=100")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let courses = try decoder.decode([Course].self, from: data)
            return courses.sorted { first, second in
                let firstString = (first.courseCode ?? "") + first.name + (first.term.isDefaultTerm ? "" : first.term.name) + (first.sections.first?.name ?? "")
                let secondString = (second.courseCode ?? "") + second.name + (second.term.isDefaultTerm ? "" : second.term.name) + (second.sections.first?.name ?? "")
                return firstString < secondString
            }
        } catch {
            logger.error("Hit error fetching courses: \(error)")
            return []
        }
    }
    
    // The assignments endpoint currently returns a 500 error. See the bug tracking this: https://github.com/instructure/canvas-lms/issues/2436
    func fetchAssignments(course: Course?) async -> [Assignment] {
        guard let course else {
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
    
    // This is the workaround for the above fetchAssignments issue.
    func fetchAssignmentsViaAssignmentGroups(course: Course?) async -> [Assignment] {
        guard let course else {
            return []
        }
        
        var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/assignment_groups?include[]=assignments&per_page=100")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let assignmentGroups = try decoder.decode([AssignmentGroup].self, from: data)
            let assignments = assignmentGroups.flatMap({ $0.assignments })
            return assignments.filter({ $0.published }).sorted(by: { $0.name < $1.name })
        } catch {
            logger.error("Hit error fetching assignments: \(error)")
            return []
        }
    }
    
    func fetchAllStudentAssignmentInfos(course: Course?) async -> [StudentAssignmentInfo] {
        guard let course else {
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
                infos.append(StudentAssignmentInfo(id: user.id, name: user.name, sortableName: user.sortableName, score: nil, grade: nil, submittedAt: nil, redoRequest: false, courseScore: user.enrollments[0].grades.currentScore, lastCourseActivityAt: user.enrollments[0].lastActivityAt))
            }
            
            return infos.sorted(by: { $0.sortableName < $1.sortableName })
        } catch {
            logger.error("Hit error fetching all studentAssignmentInfos: \(error)")
            return []
        }
    }
    
    func fetchStudentAssignmentInfos(assignment: Assignment?, course: Course?) async -> [StudentAssignmentInfo] {
        guard let assignment, let course else {
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
                var userRequest = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/courses/\(course.id)/users?enrollment_type=student&include[]=enrollments&per_page=100")!)
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
                    let assignmentInfo = StudentAssignmentInfo(id: user.id, name: user.name, sortableName: user.sortableName, score: submission?.score, grade: submission?.grade, submittedAt: submission?.submittedAt, redoRequest: submission?.redoRequest ?? false, courseScore: user.enrollments[0].grades.currentScore, lastCourseActivityAt: user.enrollments[0].lastActivityAt)
                    infos.append(assignmentInfo)
                }
            }
            
            return infos.sorted(by: { $0.sortableName < $1.sortableName })
        } catch {
            logger.error("Hit error fetching studentAssignmentInfos: \(error)")
            return []
        }
    }
    
    private func finalMessageBody(fullName: String, firstName: String, message: String) -> String {
        var message = message
        message = message.replacingOccurrences(of: Substitutions.firstName.literal, with: firstName)
        message = message.replacingOccurrences(of: Substitutions.fullName.literal, with: fullName)
        return message
    }
    
    // See https://github.com/instructure/canvas-lms/blob/22b7677b3bd608197caf012ac5304c2d6311e94c/ui/shared/grading/messageStudentsWhoHelper.ts#L92C9-L92C9
    func sendMessage(course: Course, recipients: [StudentAssignmentInfo], subject: String, isGeneric: Bool, message: String) async {
        let contextCode = "course_\(course.id)"
        
        if isGeneric {
            // No substitutions, so just send one bulk message (like the webUI does today).
            let body = finalMessageBody(fullName: "", firstName: "", message: message)
            
            var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            
            request.setValue("application/json", forHTTPHeaderField:"Content-Type");
            let postData = PostMessageData(recipients: recipients.map({ String($0.id) }), subject: subject, body: body, contextCode: contextCode)
            
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
        } else {
            for recipient in recipients {
                let body = finalMessageBody(fullName: recipient.name, firstName: recipient.firstName, message: message)
                
                var request = URLRequest(url: URL(string: "https://canvas.instructure.com/api/v1/conversations")!)
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.httpMethod = "POST"
                
                request.setValue("application/json", forHTTPHeaderField:"Content-Type");
                let postData = PostMessageData(recipients: [String(recipient.id)], subject: subject, body: body, contextCode: contextCode)
                
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
        }
    }
}
