//
//  FileBugButton.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 9/19/23.
//

import SwiftUI

struct FileBugButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "ant")
        }
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 10) {
                Text("File a bug")
                    .font(.title)
                
                Text("[Send me an email](mailto:kunzep@byui.edu?subject=Feedback%20or%20bug%20report%20for%20StudentOutreach)")
                    .font(.headline)
                
                Text("[File a Github issue](https://github.com/ephraimkunz/StudentOutreach/issues/new/choose)")
                    .font(.headline)
                
                Text("Please include a clear description of the bug you saw or the feature you are requesting, along with additional documentation like screenshots or videos.")
            }
            .padding()
            .frame(width: 200)
        }
    }
}
