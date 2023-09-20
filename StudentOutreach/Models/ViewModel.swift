//
//  ViewModel.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.ephraimkunz.StudentOutreach", category: "viewModel")

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
    
    var studentsMatchingFilter: [StudentAssignmentInfo] {
        var results = [StudentAssignmentInfo]()
        
        if let messageFilter {
            results.append(contentsOf: messageFilter.filterStudents(studentAssignmentInfos, score: messageFilterScore))
        }
        
        return results
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
        
        await networking.sendMessage(course: selectedCourse, recipients: studentsToMessage, subject: subject, isGeneric: substitutionsUsed == 0, message: message)

        Task { @MainActor in
            sendingMessage = false
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
    
    let courseScore: Double
    
    var firstName: String {
        let formatter = PersonNameComponentsFormatter()
        let comps = formatter.personNameComponents(from: name)
        return comps?.givenName ?? name
    }
}