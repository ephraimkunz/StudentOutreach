//
//  CoursePicker.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import SwiftUI

struct CoursePicker: View {
    let courses: [Course]
    @Binding var selectedCourse: Course?
    
    var body: some View {
        let courseWorkflowStates = Array(Set(courses.map { $0.workflowState })).sorted()
        
        Picker("Course:", selection: $selectedCourse) {
            Text(verbatim: "")
                .tag(nil as Course?)
            ForEach(courseWorkflowStates, id: \.self) { courseWorkflowState in
                Section(courseWorkflowState.localizedCapitalized) {
                    ForEach(courses.filter({ $0.workflowState == courseWorkflowState })) { course in
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
    }
}
