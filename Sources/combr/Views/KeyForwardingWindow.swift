import Cocoa

class KeyForwardingWindow: NSWindow {
    weak var keyDelegate: FileProcessor?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            self.close()
            return
        }
        
        if let delegate = keyDelegate, delegate.handleKeyDown(with: event) {
            return
        }
        
        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        if let responder = responder, responder.acceptsFirstResponder {
            return super.makeFirstResponder(responder)
        } else if let contentView = self.contentView, contentView.acceptsFirstResponder {
            return super.makeFirstResponder(contentView)
        }
        return super.makeFirstResponder(responder)
    }
}