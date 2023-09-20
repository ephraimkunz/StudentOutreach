//
//  SubjectAndMessageView.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import SwiftUI

struct SubjectAndMessageView: View {
    @Binding var subject: String
    @Binding var message: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Section("Subject") {
                TextField("Subject", text: $subject, prompt: Text("Enter a subject line…"))
            }
            
            Section("Message") {
                TextEditor(text: $message)
                    .font(.body)
                
                HStack {
                    ForEach(Substitutions.allCases, id: \.self) { substitution in
                        Button(substitution.literal) {
                            message.append(substitution.literal)
                        }
                        .help(substitution.explanation)
                    }
                }
            }
        }
    }
}
