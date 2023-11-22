//
//  TokenTextEditor.swift
//  StudentOutreach
//
//  Created by Ephraim Kunz on 11/22/23.
//

import SwiftUI

private let textFont = NSFont.preferredFont(forTextStyle: .body)

struct TokenTextEditor: NSViewRepresentable {
    @Binding var fullText: String
    @Binding var insertText: String
        
    func makeNSView(context: Context) -> NSScrollView {
        let scrollableTextView = NSTextView.scrollableTextView()
        let textView = scrollableTextView.documentView as! NSTextView
        textView.font = textFont
        textView.delegate = context.coordinator
        textView.string = fullText
        
        return scrollableTextView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        if !insertText.isEmpty, let range = textView.selectedRanges.first {
            let attachment = NSTextAttachment()
            attachment.attachmentCell = TokenTextAttachmentCell(text: insertText)
            let attributedString = NSAttributedString(attachment: attachment)
            textView.insertText(attributedString, replacementRange: range.rangeValue)
            
            DispatchQueue.main.async {
                fullText = textView.string
                insertText = ""
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TokenTextEditor
        
        init(_ parent: TokenTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let nsTextView = notification.object as? NSTextView {
                let attributedString = nsTextView.attributedString()
                var outputString = ""
                attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attributes, range, stop in
                    if let attachment = attributes[.attachment] as? NSTextAttachment, let attachmentCell = attachment.attachmentCell as? TokenTextAttachmentCell {
                        outputString.append(String(attachmentCell.attributedString.characters[...]))
                    } else {
                        outputString.append((attributedString.string as NSString).substring(with: range))
                    }
                }
                
                DispatchQueue.main.async {
                    self.parent.fullText = outputString
                }
            }
        }
    }
}

class TokenTextAttachmentCell: NSTextAttachmentCell {
    let attributedString: AttributedString
    
    private static let horizontalPadding: CGFloat = 4
    
    init(text: String) {
        let attributeContainer = AttributeContainer([.font: textFont, .foregroundColor: NSColor.white])
        self.attributedString = AttributedString(text, attributes: attributeContainer)
        
        super.init()
    }
    
    override init(textCell string: String) {
        fatalError()
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let roundedRect = NSBezierPath(roundedRect: cellFrame, xRadius: 4, yRadius: 4)
        NSColor.controlAccentColor.setFill()
        roundedRect.fill()
        
        let textRect = cellFrame.insetBy(dx: Self.horizontalPadding, dy: 0)
        NSAttributedString(attributedString).draw(in: textRect)
    }
    
    override nonisolated func cellSize() -> NSSize {
        let stringWidth = ceil(NSAttributedString(attributedString).size().width)

        let layoutManager = NSLayoutManager()
        let lineHeight = layoutManager.defaultLineHeight(for: textFont)
        return NSSize(width: stringWidth + (Self.horizontalPadding * 2), height: lineHeight - 1)
    }
    
    override nonisolated func cellBaselineOffset() -> NSPoint {
        return NSPoint(x: 0, y: textFont.descender)
    }
}
