//
//  SubjectAndMessageView.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import SwiftUI

struct SubjectAndMessageView: View {

  // MARK: Internal

  @Binding var subject: String
  @Binding var message: String

  var body: some View {
    VStack(alignment: .leading) {
      SwiftUI.Section("Subject") {
        TextField("Subject", text: $subject, prompt: Text("Enter a subject line…"))
          .padding(.bottom, 8)
      }

      SwiftUI.Section("Message") {
        TokenTextEditor(fullText: $message, insertText: $insertText)

        HStack {
          ForEach(Substitutions.allCases, id: \.self) { substitution in
            Button(substitution.literal) {
              insertText = substitution.literal
            }
            .help(substitution.explanation)
          }
        }
      }
    }
  }

  // MARK: Private

  @State private var insertText = ""

}
