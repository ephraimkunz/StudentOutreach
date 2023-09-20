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
    
    var formSection: some View {
        Form {
            TextField("Access Token:", text: $viewModel.accessToken)
            
            CoursePicker(courses: viewModel.courses, selectedCourse: $viewModel.selectedCourse)
            
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
                    Text(verbatim: "")
                        .tag(nil as MessageFilter?)
                    ForEach(MessageFilter.applicableFilters(assignment: viewModel.selectedAssignment, course: viewModel.selectedCourse, mode: viewModel.messageMode)) { filter in
                        Text(filter.title)
                            .tag(filter as MessageFilter?)
                    }
                }
                
                if let messageFilter = viewModel.messageFilter, messageFilter.scoreNeeded {
                    TextField("Score:", value: $viewModel.messageFilterScore, formatter: NumberFormatter())
#if !os(macOS)
                        .keyboardType(.numberPad)
#endif
                }
            } else {
                Picker("Message Students Who:", selection: $viewModel.messageFilter) {
                    Text(verbatim: "")
                        .tag(nil as MessageFilter?)
                    ForEach(MessageFilter.applicableFilters(assignment: viewModel.selectedAssignment, course: viewModel.selectedCourse, mode: viewModel.messageMode)) { filter in
                        Text(filter.title)
                            .tag(filter as MessageFilter?)
                    }
                }
                
                if let messageFilter = viewModel.messageFilter, messageFilter.scoreNeeded {
                    TextField("Course Score:", value: $viewModel.messageFilterScore, formatter: NumberFormatter())
#if !os(macOS)
                        .keyboardType(.numberPad)
#endif
                }
            }
        }
    }
    
    var messageSection: some View {
        HStack(alignment: .top) {
            RecipientsView(students: viewModel.studentsMatchingFilter, enabledStudentsCount: viewModel.studentsToMessage.count, disabledStudentIds: $viewModel.disabledStudentIds)
                .frame(width: 230)
            
            Divider()
            
            SubjectAndMessageView(subject: $viewModel.subject, message: $viewModel.message)
        }
        .frame(minWidth: 600, minHeight: 300)
    }
    
    var sendSection: some View {
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
    
    var body: some View {
        VStack(spacing: 30) {
            formSection
            
            messageSection
            
            sendSection
        }
        .padding()
        .task {
            viewModel.accessToken = accessToken
        }
        .onChange(of: viewModel.accessToken) { newAccessToken in
            accessToken = newAccessToken
        }
        .toolbar {
            FileBugButton()
        }
    }
}
