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
                    let disabled = disabledStudentIds.contains(student.id)
                    HStack {
                        Text(student.name)
                            .lineLimit(1)
                            .strikethrough(disabled)
                        
                        Spacer()
                        
                        Button {
                            if disabled {
                                disabledStudentIds.remove(student.id)
                            } else {
                                disabledStudentIds.insert(student.id)
                            }
                        } label: {
                            Image(systemName: disabled ? "plus" : "xmark")
                        }
                    }
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
