import Cocoa

class EscapeHandlingTextView: NSTextView {
    weak var processor: FileProcessor?
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            processor?.window.close()
            return
        }
        super.keyDown(with: event)
    }
}