//
//  ViewModel.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation
import os.log

class ViewModel: ObservableObject {
    var networking = Networking(accessToken: "")
    
    @Published var accessToken = "" {
        didSet {
            networking = Networking(accessToken: accessToken)
            
            Task { @MainActor in
                courses = await networking.fetchCourses()
            }
        }
    }
    
    @Published var courses: [Course] = []
    @Published var selectedCourse: Course? = nil {
        didSet {
            Task { @MainActor in
                if messageMode == .assignment {
                    assignments = await networking.fetchAssignments(course: selectedCourse)
                } else {
                    studentAssignmentInfos = await networking.fetchAllStudentAssignmentInfos(course: selectedCourse)
                }
            }
        }
    }
    
    @Published var assignments: [Assignment] = []
    @Published var selectedAssignment: Assignment? = nil {
        didSet {
            Task { @MainActor in
                studentAssignmentInfos = await networking.fetchStudentAssignmentInfos(assignment: selectedAssignment, course: selectedCourse)
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
    @Published var messageFilterScore2: Double = 100 {
        didSet {
            generateSubject()
            disabledStudentIds.removeAll()
        }
    }
    @Published var messageMode: MessageMode = .assignment {
        didSet {
            Task { @MainActor in
                if messageMode == .assignment {
                    assignments = await networking.fetchAssignments(course: selectedCourse)
                } else {
                    studentAssignmentInfos = await networking.fetchAllStudentAssignmentInfos(course: selectedCourse)
                }
            }
        }
    }
    
    @Published var searchTerm: String = ""
    
    @Published var subject = "" {
        didSet {
            messageSendState = .unsent
        }
    }
    @Published var message = "" {
        didSet {
            messageSendState = .unsent
        }
    }
    
    @Published var disabledStudentIds: Set<Int> = [] {
        didSet {
            messageSendState = .unsent
        }
    }
    
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
    
    var studentsMatchingFilter: [StudentAssignmentInfo] {
        var results = [StudentAssignmentInfo]()
        
        if let messageFilter {
            results.append(contentsOf: messageFilter.filterStudents(studentAssignmentInfos, score: messageFilterScore, score2: messageFilterScore2))
        }
        
        return results
    }
    
    func generateSubject() {
        if let messageFilter {
            if let selectedCourse {
                subject = messageFilter.subject(assignmentName: selectedAssignment?.name, score: messageFilterScore, score2: messageFilterScore2, courseName: selectedCourse.name)
            }
        } else {
            subject = ""
        }
    }
    
    @Published var messageSendState: MessageSendState = .unsent
    
    func sendMessage() async {
        guard let selectedCourse else {
            return
        }
        
        Task { @MainActor in
            messageSendState = .sending
        }
        
        await networking.sendMessage(course: selectedCourse, recipients: studentsToMessage, subject: subject, isGeneric: substitutionsUsed == 0, message: message)

        Task { @MainActor in
            messageSendState = .sent
        }
    }
}

struct StudentAssignmentInfo: Hashable {
    let id: Int
    let name: String
    let sortableName: String
    let score: Double?
    let grade: String?
    let submittedAt: Date?
    let redoRequest: Bool
    
    let courseScore: Double?
    
    var firstName: String {
        let formatter = PersonNameComponentsFormatter()
        let comps = formatter.personNameComponents(from: name)
        return comps?.givenName ?? name
    }
    let lastCourseActivityAt: Date?
}

enum MessageSendState {
    case unsent, sending, sent
    
    var title: String {
        switch self {
        case .unsent:
            "Send"
        case .sending:
            "Sending"
        case .sent:
            "Message sent!"
        }
    }
}
