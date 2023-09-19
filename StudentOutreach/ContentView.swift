//
//  ContentView.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/15/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
    @AppStorage("access-token") private var accessToken: String = ""
    @State private var presentingSendConfirmation = false
    
    var body: some View {
        VStack(spacing: 30) {
            Form {
                TextField("Access Token:", text: $viewModel.accessToken)
                
                let courseWorkflowStates = Array(Set(viewModel.courses.map { $0.workflowState })).sorted()
                
                Picker("Course:", selection: $viewModel.selectedCourse) {
                    Text("")
                        .tag(nil as Course?)
                    ForEach(courseWorkflowStates, id: \.self) { courseWorkflowState in
                        Section(courseWorkflowState.localizedCapitalized) {
                            ForEach(viewModel.courses.filter({ $0.workflowState == courseWorkflowState })) { course in
                                Group {
                                    if let courseCode = course.courseCode, courseCode != course.name {
                                        if course.term.isDefaultTerm {
                                            Text("\(courseCode) - \(course.name)")
                                        } else {
                                            Text("\(courseCode) - \(course.name) - \(course.term.name)")
                                        }
                                    } else {
                                        if course.term.isDefaultTerm {
                                            Text("\(course.name)")
                                        } else {
                                            Text("\(course.name) - \(course.term.name)")
                                        }
                                    }
                                }
                                .tag(course as Course?)
                            }
                        }
                    }
                }
                
                Picker("Mode:", selection: $viewModel.messageMode) {
                    ForEach(MessageMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                    }
                }
                
                if viewModel.messageMode == .assignment {
                    Picker("Assignment:", selection: $viewModel.selectedAssignment) {
                        Text("")
                            .tag(nil as Assignment?)
                        ForEach(viewModel.assignments) { assignment in
                            Text(assignment.name)
                                .tag(assignment as Assignment?)
                        }
                    }
                    
                    Picker("Message Students Who:", selection: $viewModel.messageFilter) {
                        ForEach(MessageFilter.allCases) { filter in
                            Text(filter.title)
                        }
                    }
                    
                    if viewModel.messageFilter.scoreNeeded {
                        TextField("Score:", value: $viewModel.messageFilterScore, formatter: NumberFormatter())
#if !os(macOS)
                            .keyboardType(.numberPad)
#endif
                    }
                }
            }
            
            HStack(alignment: .top) {
                VStack {
                    let numEnabled = viewModel.studentsToMessage.count
                    Text("Recipients (\(numEnabled))")
                    
                    TextField("Search", text: $viewModel.searchTerm)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    List {
                        ForEach(viewModel.studentsMatchingFilter.filter({ viewModel.searchTerm.isEmpty ? true : $0.name.lowercased().contains(viewModel.searchTerm.lowercased())} ), id: \.self) { student in
                            let disabled = viewModel.disabledStudentIds.contains(student.id)
                            HStack {
                                Text(student.name)
                                    .lineLimit(1)
                                    .strikethrough(disabled)
                                
                                Spacer()
                                
                                Button {
                                    if disabled {
                                        viewModel.disabledStudentIds.remove(student.id)
                                    } else {
                                        viewModel.disabledStudentIds.insert(student.id)
                                    }
                                } label: {
                                    Image(systemName: disabled ? "plus" : "xmark")
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Button("Enable All") {
                            viewModel.disabledStudentIds.removeAll()
                        }
                        .disabled(viewModel.disabledStudentIds.isEmpty)
                        
                        Button("Disable All") {
                            viewModel.disabledStudentIds.formUnion(viewModel.studentsMatchingFilter.map({ $0.id }))
                        }
                        .disabled(viewModel.disabledStudentIds.count == viewModel.studentsMatchingFilter.count)
                    }
                }
                .frame(width: 230)
                
                Divider()
                
                VStack(alignment: .leading) {
                    Section("Subject") {
                        TextField("Subject", text: $viewModel.subject, prompt: Text("Enter a subject line…"))
                    }
                    
                    Section("Message") {
                        TextEditor(text: $viewModel.message)
                            .font(.body)
                        
                        HStack {
                            ForEach(Substitutions.allCases, id: \.self) { substitution in
                                Button(substitution.literal) {
                                    viewModel.message.append(substitution.literal)
                                }
                                .help(substitution.explanation)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 300)
            
            HStack {
                Spacer()
                
                Button {
                    presentingSendConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Text(viewModel.sendingMessage ? "Sending" : "Send")
                        
                        if viewModel.sendingMessage {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(viewModel.message.isEmpty || viewModel.studentsToMessage.isEmpty)
                .confirmationDialog("Send Message", isPresented: $presentingSendConfirmation, actions: {
                    Button("Send") {
                        print(viewModel.finalMessageBody(fullName: "Ephraim Kunz", firstName: "Ephraim"))
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                }, message: {
                    Text("This message will be sent to \(viewModel.studentsToMessage.count) recipients. The message is using \(viewModel.substitutionsUsed) substitutions.")
                })
            }
        }
        .padding()
        .task {
            viewModel.accessToken = accessToken
        }
        .onChange(of: viewModel.accessToken) { newAccessToken in
            accessToken = newAccessToken
        }
    }
}

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
            switch self.messageFilter {
            case .notSubmitted:
                results.append(contentsOf: studentAssignmentInfos.filter({ !$0.submitted }))
            case .notGraded:
                results.append(contentsOf: studentAssignmentInfos.filter({ $0.score == nil }))
            case .scoredMoreThan:
                results.append(contentsOf: studentAssignmentInfos.filter { student in
                    if let score = student.score {
                        return score > messageFilterScore
                    }
                    
                    return false
                })
            case .scoredLessThan:
                results.append(contentsOf: studentAssignmentInfos.filter { student in
                    if let score = student.score {
                        return score < messageFilterScore
                    }
                    
                    return false
                })
            case .reassigned:
                results.append(contentsOf: studentAssignmentInfos)
            }
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

enum MessageFilter: CaseIterable, Identifiable {
    case notSubmitted, notGraded, scoredMoreThan, scoredLessThan, reassigned
    
    var id: Self {
        return self
    }
    
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
        case .reassigned:
            return "Reassigned"
        }
    }
    
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
        case .reassigned:
            return "\(assignmentName) is reassigned"
        }
    }
    
    var scoreNeeded: Bool {
        switch self {
        case .scoredLessThan, .scoredMoreThan:
            return true
        default:
            return false
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
