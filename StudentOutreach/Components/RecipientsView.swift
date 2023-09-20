//
//  RecipientsView.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import SwiftUI

struct RecipientsView: View {
    let students: [StudentAssignmentInfo]
    let enabledStudentsCount: Int
    @Binding var disabledStudentIds: Set<Int>
    @State private var searchTerm = ""
    
    var body: some View {
        VStack {
            Text("Recipients (\(enabledStudentsCount))")
            
            TextField("Search", text: $searchTerm)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            List {
                ForEach(students.filter({ searchTerm.isEmpty ? true : $0.name.lowercased().contains(searchTerm.lowercased())} ), id: \.self) { student in
                    StudentCell(disabledStudentIds: $disabledStudentIds, student: student)
                }
            }
            
            HStack {
                Button("Enable All") {
                    disabledStudentIds.removeAll()
                }
                .disabled(disabledStudentIds.isEmpty)
                
                Button("Disable All") {
                    disabledStudentIds.formUnion(students.map({ $0.id }))
                }
                .disabled(disabledStudentIds.count == students.count)
            }
        }
    }
}

struct StudentCell: View {
    @Binding var disabledStudentIds: Set<Int>
    let student: StudentAssignmentInfo
    
    @State private var toggleEnabled = false
    
    var body: some View {
        HStack {
            Text(student.name)
                .lineLimit(1)
                .strikethrough(disabledStudentIds.contains(student.id))
            
            Spacer()
            
            Toggle("Enabled", isOn: $toggleEnabled)
                .labelsHidden()
        }
        .task {
            updateToggleEnabled()
        }
        .onChange(of: disabledStudentIds) { newValue in
            updateToggleEnabled()
        }
        .onChange(of: toggleEnabled) { newValue in
            if disabledStudentIds.contains(student.id) {
                disabledStudentIds.remove(student.id)
            } else {
                disabledStudentIds.insert(student.id)
            }
            
            updateToggleEnabled()
        }
    }
    
    func updateToggleEnabled() {
        toggleEnabled = !disabledStudentIds.contains(student.id)
    }
}
