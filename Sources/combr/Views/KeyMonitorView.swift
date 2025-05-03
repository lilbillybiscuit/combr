import Cocoa

class KeyMonitorView: NSView {
    weak var processor: FileProcessor?
    
    override var acceptsFirstResponder: Bool { return true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        if let layer = self.layer {
            layer.masksToBounds = false
            layer.isOpaque = false
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            processor?.window.close()
            return
        }
        
        switch event.keyCode {
        case 36: // Enter key
            processor?.confirmClicked()
        case 49: // Spacebar
            processor?.toggleSelectedItem()
        case 125: // Down arrow
            processor?.selectNextItem()
        case 126: // Up arrow
            processor?.selectPreviousItem()
        default:
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if window?.firstResponder != self {
            self.window?.makeFirstResponder(self)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}