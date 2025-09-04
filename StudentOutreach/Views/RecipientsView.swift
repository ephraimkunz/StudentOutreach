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
            .border(Color(NSColor.secondarySystemFill), width: 1)
            
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
        
    var body: some View {
        HStack {
            Text(student.name)
                .strikethrough(disabledStudentIds.contains(student.id))
                .lineLimit(1)
            
            Spacer()
            
            Toggle("Enabled", isOn: Binding(get: {
                !disabledStudentIds.contains(student.id)
            }, set: { newValue in
                if newValue {
                    disabledStudentIds.remove(student.id)
                } else {
                    disabledStudentIds.insert(student.id)
                }
            }))
            .labelsHidden()
        }
    }
}
