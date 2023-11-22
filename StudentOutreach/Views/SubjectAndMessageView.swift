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
    @State private var insertText = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Section("Subject") {
                TextField("Subject", text: $subject, prompt: Text("Enter a subject line…"))
            }
            
            Section("Message") {
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
}
