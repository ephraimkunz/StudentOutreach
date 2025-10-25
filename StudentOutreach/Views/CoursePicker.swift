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
        SwiftUI.Section(courseWorkflowState.localizedCapitalized) {
          ForEach(courses.filter { $0.workflowState == courseWorkflowState }) { course in
            Group {
              let sectionName = " - \(course.sections.first?.name ?? "")"
              if let courseCode = course.courseCode, courseCode != course.name {
                if course.term.isDefaultTerm {
                  Text("\(courseCode) - \(course.name)" + sectionName)
                } else {
                  Text("\(courseCode) - \(course.name) - \(course.term.name)" + sectionName)
                }
              } else {
                if course.term.isDefaultTerm {
                  Text("\(course.name)" + sectionName)
                } else {
                  Text("\(course.name) - \(course.term.name)" + sectionName)
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
