import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var processor: FileProcessor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
            print("""
            Usage: \(CommandLine.arguments[0]) [options]

            Options:
              --ext=<extension>    Specify file extensions to auto-select (default: common code files).
                                   Can be used multiple times (e.g., --ext=py --ext=js).
              --exclude=<pattern>  Specify a file/directory name pattern to exclude (e.g., --exclude=*.log).
                                   Uses wildcard matching (*, ?). Applied after default excludes.
                                   Can be used multiple times. Matches filename OR full path.
              --include=<pattern>  Specify a file/directory name pattern to force include, overriding default excludes.
                                   (e.g., --include=build/important.txt). Uses wildcard matching.
                                   Can be used multiple times. Matches filename OR full path.
              --help, -h           Show this help message and exit.

            Default Exclusions: \(FileProcessor().defaultExclusionPatterns.joined(separator: ", "))
            Default Extensions: \(FileProcessor().defaultExtensions.joined(separator: ", "))

            Description:
              Scans the current directory, allowing selection of files. Copies the content
              of selected files, prefixed with their relative paths, to the clipboard upon 'Confirm'.

            Keyboard Shortcuts:
              Enter: Confirm and copy to clipboard
              Esc:   Close the window
              Space: Toggle selection of the highlighted item
              Up/Down Arrow: Navigate the file list
            """)
            NSApplication.shared.terminate(nil)
            return
        }
        
        NSApp.setActivationPolicy(.accessory)
        processor = FileProcessor()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            NSApp.activate(ignoringOtherApps: true)
            self.processor.window.orderFrontRegardless()
            
            if let keyMonitorView = self.processor.window.contentView as? KeyMonitorView {
                self.processor.window.makeFirstResponder(keyMonitorView)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        processor?.window.orderFrontRegardless()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        processor?.window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        processor?.window.orderFrontRegardless()
    }
}