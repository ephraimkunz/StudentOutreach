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
                    Text(verbatim: "")
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
                        Text(verbatim: "")
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
