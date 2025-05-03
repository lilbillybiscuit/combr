import Cocoa

class FileProcessor: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSWindowDelegate {
    var window: NSWindow!
    var outlineView: NSOutlineView!
    var textView: NSTextView!
    var rootItem: FileItem!
    var statusLabel: NSTextField! 
    
    var useCustomTextCheckbox: NSButton!
    var startTextField: NSTextField!
    var endTextField: NSTextField!
    var useCustomText: Bool = false
    var customStartText: String = "=== Start Content ==="
    var customEndText: String = "=== End Content ==="

    let defaultExtensions = ["swift", "py", "js", "java", "cpp", "h", "c", "rb", "go", "kt", "m", "mm", "ts", "tsx", "cs", "php", "html", "css", "scss", "json", "xml", "yaml", "yml", "md", "sh"]
    let defaultExclusionPatterns = [".git", "node_modules", "__pycache__", ".venv", "venv", "build", "dist", ".DS_Store", "*.pyc", "*.o", "*.class", "*.exe", "*.dll", "*.so", "*.dylib", "*.dSYM", "*.app", "*.framework", "*.xcassets", "*.xcodeproj", "*.xcworkspace"]

    var allowedExtensions: Set<String>
    var exclusionPatterns: Set<String>
    var inclusionPatterns: Set<String> 

    override init() {
        var cmdExtensions: [String] = []
        var cmdExclusions: [String] = []
        var cmdInclusions: [String] = []

        let args = CommandLine.arguments
        for arg in args.dropFirst() {
            if arg.hasPrefix("--ext=") {
                let ext = String(arg.dropFirst("--ext=".count)).lowercased()
                if !ext.isEmpty { cmdExtensions.append(ext) }
            } else if arg.hasPrefix("--exclude=") {
                let pattern = String(arg.dropFirst("--exclude=".count))
                 if !pattern.isEmpty { cmdExclusions.append(pattern) }
            } else if arg.hasPrefix("--include=") {
                 let pattern = String(arg.dropFirst("--include=".count))
                 if !pattern.isEmpty { cmdInclusions.append(pattern) }
            }
        }

        allowedExtensions = Set(cmdExtensions.isEmpty ? defaultExtensions : cmdExtensions)
        exclusionPatterns = Set(defaultExclusionPatterns).union(cmdExclusions)
        inclusionPatterns = Set(cmdInclusions)

        super.init()
        
        setupWindow()
        outlineView.dataSource = nil
        loadCurrentDirectory()
    }
    
    func setupTextView() {
        textView = NSTextView()
        textView.isEditable = false
        
        if #available(macOS 10.15, *) {
            textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            textView.font = NSFont(name: "Menlo", size: 12) ?? NSFont.userFixedPitchFont(ofSize: 12)
        }
        
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.labelColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        
        let customTextView = EscapeHandlingTextView(frame: .zero)
        customTextView.isEditable = false
        
        if #available(macOS 10.15, *) {
            customTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            customTextView.font = NSFont(name: "Menlo", size: 12) ?? NSFont.userFixedPitchFont(ofSize: 12)
        }
        
        customTextView.drawsBackground = true
        customTextView.backgroundColor = NSColor.textBackgroundColor
        customTextView.textColor = NSColor.labelColor
        customTextView.isVerticallyResizable = true
        customTextView.isHorizontallyResizable = true
        customTextView.textContainer?.widthTracksTextView = true
        customTextView.processor = self
        
        textView = customTextView
    }

    func shouldExclude(filename: String, fullPath: String, isDirectory: Bool) -> Bool {
        for pattern in inclusionPatterns {
            if wildCardMatch(pattern, filename) || wildCardMatch(pattern, fullPath) {
                return false 
            }
        }
        
        for pattern in exclusionPatterns {
            if wildCardMatch(pattern, filename) || wildCardMatch(pattern, fullPath) {
                return true 
            }
        }
        
        return false
    }

    func toggleSelectedItem() {
        let selectedRow = outlineView.selectedRow
        if selectedRow >= 0, let item = outlineView.item(atRow: selectedRow) as? FileItem {
            let newStateSelected = !item.isSelected
            
            outlineView.beginUpdates()
            
            var itemsToReload = Set<FileItem>()
            
            applyStateChange(to: item, newState: newStateSelected, itemsToReload: &itemsToReload)
            
            for itemToReload in itemsToReload {
                if itemToReload.isDirectory {
                    outlineView.reloadItem(itemToReload, reloadChildren: true)
                } else {
                    outlineView.reloadItem(itemToReload)
                }
            }
            
            outlineView.endUpdates()
            
            updateTextView()
        }
    }

    func selectNextItem() {
        let currentRow = outlineView.selectedRow
        let nextRow = currentRow + 1

        if nextRow < outlineView.numberOfRows {
            outlineView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
            outlineView.scrollRowToVisible(nextRow)
        }
    }

    func selectPreviousItem() {
        let currentRow = outlineView.selectedRow
        let previousRow = currentRow - 1

        if previousRow >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
            outlineView.scrollRowToVisible(previousRow)
        }
    }

    func shouldAutoSelectFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return allowedExtensions.contains(ext)
    }

    @objc func customTextCheckboxClicked(_ sender: NSButton) {
        useCustomText = (sender.state == .on)
        startTextField.isEnabled = useCustomText
        endTextField.isEnabled = useCustomText
        updateTextView()
    }
    
    @objc func customTextFieldChanged(_ sender: NSTextField) {
        if useCustomText {
           updateTextView()
        }
    }
    
    func setupWindow() {
        let rect = NSRect(x: 0, y: 0, width: 800, height: 600)
        
        window = KeyForwardingWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "File Processor"
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        NSApp.setActivationPolicy(.accessory)
        
        let keyMonitorView = KeyMonitorView()
        keyMonitorView.processor = self
        window.contentView = keyMonitorView
        
        (window as? KeyForwardingWindow)?.keyDelegate = self
        
        let visualEffectView = NSVisualEffectView()
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        keyMonitorView.addSubview(visualEffectView)
        
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        
        let outlineScrollView = NSScrollView()
        outlineScrollView.hasVerticalScroller = true
        outlineScrollView.hasHorizontalScroller = true
        outlineScrollView.autohidesScrollers = true
        outlineScrollView.borderType = .noBorder
        outlineScrollView.drawsBackground = false
        outlineScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        outlineView = NSOutlineView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Files"))
        column.title = "Files"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.allowsMultipleSelection = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = .clear
        outlineView.sizeLastColumnToFit()
        
        outlineScrollView.documentView = outlineView
        
        let textScrollView = NSScrollView()
        textScrollView.hasVerticalScroller = true
        textScrollView.hasHorizontalScroller = true
        textScrollView.autohidesScrollers = true
        textScrollView.borderType = .noBorder
        textScrollView.drawsBackground = true
        textScrollView.backgroundColor = NSColor.textBackgroundColor
        textScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let customTextView = EscapeHandlingTextView(frame: .zero)
        customTextView.isEditable = false
        
        if #available(macOS 10.15, *) {
            customTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        } else {
            customTextView.font = NSFont(name: "Menlo", size: 12) ?? NSFont.userFixedPitchFont(ofSize: 12)
        }
        
        customTextView.drawsBackground = true
        customTextView.backgroundColor = NSColor.textBackgroundColor
        customTextView.textColor = NSColor.labelColor
        customTextView.isVerticallyResizable = true
        customTextView.isHorizontallyResizable = true
        customTextView.textContainer?.widthTracksTextView = true
        customTextView.processor = self
        
        textView = customTextView
        
        textScrollView.documentView = textView
        
        splitView.addArrangedSubview(outlineScrollView)
        splitView.addArrangedSubview(textScrollView)
        
        useCustomTextCheckbox = NSButton(checkboxWithTitle: "Use custom text for start/end", target: self, action: #selector(customTextCheckboxClicked(_:)))
        useCustomTextCheckbox.translatesAutoresizingMaskIntoConstraints = false
        useCustomTextCheckbox.state = .off
        
        let startLabel = NSTextField(labelWithString: "Start:")
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        
        startTextField = NSTextField(string: customStartText)
        startTextField.translatesAutoresizingMaskIntoConstraints = false
        startTextField.isEnabled = false  
        startTextField.target = self
        startTextField.action = #selector(customTextFieldChanged(_:))
        
        let endLabel = NSTextField(labelWithString: "End:")
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        
        endTextField = NSTextField(string: customEndText)
        endTextField.translatesAutoresizingMaskIntoConstraints = false
        endTextField.isEnabled = false  
        endTextField.target = self
        endTextField.action = #selector(customTextFieldChanged(_:))
        
        let customTextStack = NSStackView(views: [useCustomTextCheckbox, startLabel, startTextField, endLabel, endTextField])
        customTextStack.orientation = .horizontal
        customTextStack.spacing = 8
        customTextStack.translatesAutoresizingMaskIntoConstraints = false
        
        let confirmButton = NSButton(title: "Confirm", target: self, action: #selector(confirmClicked))
        confirmButton.bezelStyle = .rounded
        confirmButton.setButtonType(.momentaryPushIn)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.alignment = .right
        
        let bottomControlsStack = NSStackView(views: [statusLabel, confirmButton])
        bottomControlsStack.orientation = .horizontal
        bottomControlsStack.spacing = 8
        bottomControlsStack.distribution = .fill
        bottomControlsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let allBottomControls = NSStackView(views: [customTextStack, bottomControlsStack])
        allBottomControls.orientation = .vertical
        allBottomControls.spacing = 8
        allBottomControls.distribution = .fill
        allBottomControls.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStackView = NSStackView(views: [splitView, allBottomControls])
        mainStackView.orientation = .vertical
        mainStackView.spacing = 5
        mainStackView.distribution = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        visualEffectView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: keyMonitorView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: keyMonitorView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: keyMonitorView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: keyMonitorView.bottomAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 4),
            mainStackView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 4),
            mainStackView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -4),
            mainStackView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -4),
            
            splitView.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),
            
            splitView.heightAnchor.constraint(equalTo: mainStackView.heightAnchor, constant: -60), 
            
            startTextField.widthAnchor.constraint(equalToConstant: 150),
            endTextField.widthAnchor.constraint(equalToConstant: 150),
            
            outlineScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            textScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            
            bottomControlsStack.heightAnchor.constraint(equalToConstant: 24),
            customTextStack.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        DispatchQueue.main.async {
            let totalWidth = self.window.frame.width - 8
            let position = totalWidth / 3
            splitView.setPosition(position, ofDividerAt: 0)
        }
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(keyMonitorView)
        window.center()
        
        DispatchQueue.main.async {
            self.updateTextView()
        }
    }

    func loadCurrentDirectory() {
        let currentPath = FileManager.default.currentDirectoryPath
        
        do {
            if let validRoot = FileItem(path: currentPath, processor: self) {
                self.rootItem = validRoot
            } else {
                var isDirFallback: ObjCBool = false
                let existsFallback = FileManager.default.fileExists(atPath: currentPath, isDirectory: &isDirFallback)
                
                if existsFallback {
                    self.rootItem = FileItem(path: currentPath, isDirectory: isDirFallback.boolValue, processor: self)
                    if self.rootItem.isDirectory {
                        self.rootItem.loadChildren(processor: self)
                    }
                } else {
                    self.rootItem = FileItem(path: "Error", isDirectory: true, processor: self)
                    self.rootItem.children = []
                }
            }
        }
        
        if self.rootItem == nil {
            self.rootItem = FileItem(path: "Error", isDirectory: true, processor: self)
            self.rootItem.children = []
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.outlineView.dataSource = self
            
            self.outlineView.reloadData()
            self.outlineView.expandItem(self.rootItem)

            if self.outlineView.numberOfRows > 1 {
                self.outlineView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
                self.outlineView.scrollRowToVisible(1)
            } else if self.outlineView.numberOfRows > 0 {
                self.outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self.outlineView.scrollRowToVisible(0)
            }

            self.updateTextView()

            if let keyMonitor = self.window.contentView as? KeyMonitorView {
                _ = self.window.makeFirstResponder(keyMonitor)
            }
        }
    }

    @objc func confirmClicked() {
        let outputString = textView.string
        let charCount = outputString.count
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputString, forType: .string)
        
        print("\(charCount) characters copied to clipboard")
        
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard rootItem != nil else {
            return 0
        }
        
        if item == nil {
            return 1 
        }

        guard let fileItem = item as? FileItem else {
            return 0
        }
        
        return fileItem.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let root = rootItem else {
            let dummy = FileItem(path: "Error", isDirectory: true, processor: self)
            dummy.children = []
            return dummy
        }
        
        if item == nil {
            return root
        }

        guard let fileItem = item as? FileItem,
            let children = fileItem.children,
            index < children.count else {
            let dummy = FileItem(path: "Error", isDirectory: false, processor: self)
            return dummy
        }
        
        return children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard rootItem != nil else { return false }
        guard let fileItem = item as? FileItem else { return false }
        
        return fileItem.isDirectory && (fileItem.children?.count ?? 0) > 0
    }

    // MARK: - NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileItem = item as? FileItem else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("FileCell")
        var view = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        var checkbox: NSButton!
        var label: NSTextField!

        if view == nil {
            view = NSTableCellView()
            view?.identifier = identifier

            checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxClicked(_:)))
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            checkbox.allowsMixedState = true

            label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isEditable = false
            label.isBordered = false
            label.backgroundColor = .clear
            label.lineBreakMode = .byTruncatingTail

            view?.addSubview(checkbox)
            view?.addSubview(label)
            view?.textField = label

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            view?.addSubview(imageView)
            view?.imageView = imageView

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                checkbox.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 2),
                checkbox.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
                checkbox.widthAnchor.constraint(equalToConstant: 18),

                label.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view!.trailingAnchor, constant: -2)
            ])
        } else {
            checkbox = view?.subviews.first(where: { $0 is NSButton }) as? NSButton
            label = view?.textField
        }

        label.stringValue = (fileItem.path as NSString).lastPathComponent
        
        if fileItem.isDirectory {
            let calculatedState = calculateFolderState(fileItem)
            checkbox.state = calculatedState
        } else {
            checkbox.state = fileItem.isSelected ? .on : .off
        }

        let icon = NSWorkspace.shared.icon(forFile: fileItem.path)
        icon.size = NSSize(width: 16, height: 16)
        view?.imageView?.image = icon

        return view
    }
    
    private func calculateFolderState(_ item: FileItem) -> NSControl.StateValue {
        guard item.isDirectory, let children = item.children, !children.isEmpty else {
            return item.isSelected ? .on : .off
        }
        
        var selectedCount = 0
        
        for child in children {
            if child.isDirectory {
                let childState = calculateFolderState(child)
                if childState == .on || childState == .mixed {
                    selectedCount += 1
                }
            } else if child.isSelected {
                selectedCount += 1
            }
        }
        
        if selectedCount == 0 {
            return item.isSelected ? .on : .off
        } else if selectedCount == children.count {
            return .on
        } else {
            return .mixed
        }
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 20
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
    }

    @objc func checkboxClicked(_ sender: NSButton) {
        guard let cellView = sender.superview as? NSTableCellView else {
            print("Error: Checkbox superview is not NSTableCellView")
            return
        }
        let row = outlineView.row(for: cellView)
        guard row >= 0,
            let item = outlineView.item(atRow: row) as? FileItem else {
            print("Error: Could not find item for checkbox at row \(row)")
            return
        }
        
        let newStateSelected = !item.isSelected
        
        outlineView.beginUpdates()

        var itemsToReload = Set<FileItem>()
        
        applyStateChange(to: item, newState: newStateSelected, itemsToReload: &itemsToReload)
        
        for itemToReload in itemsToReload {
            if itemToReload.isDirectory {
                outlineView.reloadItem(itemToReload, reloadChildren: true)
            } else {
                outlineView.reloadItem(itemToReload)
            }
        }
        
        outlineView.endUpdates()

        updateTextView()
    }
    
    private func applyStateChange(to item: FileItem, newState: Bool, itemsToReload: inout Set<FileItem>) {
        item.isSelected = newState
        itemsToReload.insert(item)
        
        if item.isDirectory, let children = item.children {
            for child in children {
                applyStateChange(to: child, newState: newState, itemsToReload: &itemsToReload)
            }
        }
        
        updateParents(of: item, itemsToReload: &itemsToReload)
    }
    
    private func updateParents(of item: FileItem, itemsToReload: inout Set<FileItem>) {
        var currentItem = item
        var parent = outlineView.parent(forItem: currentItem) as? FileItem
        
        while parent != nil {
            itemsToReload.insert(parent!)
            
            if parent!.isDirectory, let children = parent!.children, !children.isEmpty {
                let hasSelectedChildren = children.contains { 
                    $0.isSelected || (
                        $0.isDirectory && 
                        calculateFolderState($0) != .off
                    )
                }
                
                if hasSelectedChildren && !parent!.isSelected {
                    parent!.isSelected = true
                } else if !hasSelectedChildren && parent!.isSelected {
                    parent!.isSelected = false
                }
            }
            
            currentItem = parent!
            parent = outlineView.parent(forItem: currentItem) as? FileItem
        }
    }
    
    func handleKeyDown(with event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36: // Enter key
            confirmClicked()
            return true 
        case 53: // Escape key
            window.close()
            return true 
        case 49: // Spacebar
            toggleSelectedItem()
            return true 
        case 125: // Down arrow
            selectNextItem()
            return true 
        case 126: // Up arrow
            selectPreviousItem()
            return true 
        default:
            return false 
        }
    }

    func updateTextView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.performTextViewUpdate()
        }
    }
    
    private func performTextViewUpdate() {
        let currentPath = FileManager.default.currentDirectoryPath
        let isCustomEnabled = self.useCustomText 
        let customStartTextValue = self.startTextField.stringValue 
        let customEndTextValue = self.endTextField.stringValue     
        
        guard let rootItemRef = self.rootItem else {
            DispatchQueue.main.async { [weak self] in
                self?.textView.string = ""
                self?.statusLabel.stringValue = "Error: File data not available."
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var output: String = ""
            var fileCount: Int = 0

            func processItemInBackgroundLineByLine(_ item: FileItem) {
                guard let processor = self else { return }

                if !item.isDirectory && item.isSelected {
                    let commentStyle = processor.getCommentStyle(forPath: item.path)

                    do {
                        let relativePath = item.path.replacingOccurrences(of: currentPath + "/", with: "")
                        let fileContent = try String(contentsOfFile: item.path, encoding: .utf8)
                        
                        output += "\(commentStyle) File: \(relativePath)\n"
                        
                        if isCustomEnabled {
                            output += "\(commentStyle) \(customStartTextValue)\n"
                        }
                        
                        output += fileContent
                        
                        if isCustomEnabled && !fileContent.hasSuffix("\n") {
                            output += "\n"
                        }

                        if isCustomEnabled {
                             output += "\(commentStyle) \(customEndTextValue)\n\n"
                        } else {
                            output += "\n\n"
                        }

                        fileCount += 1
                    } catch {
                        print("Error reading file \(item.path): \(error)")
                    }
                }

                if item.isDirectory, let children = item.children {
                    children.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                            .forEach { processItemInBackgroundLineByLine($0) }
                }
            } 

            if !rootItemRef.isDirectory && rootItemRef.isSelected {
                processItemInBackgroundLineByLine(rootItemRef)
            } else if rootItemRef.isDirectory, let children = rootItemRef.children {
                children.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                        .forEach { processItemInBackgroundLineByLine($0) }
            }

            DispatchQueue.main.async {
                guard let processor = self else { return }
                processor.textView.string = output 
                let charCount = output.count
                processor.statusLabel.stringValue = "\(charCount) chars (\(fileCount) files)"
            }
        }  
    }
    
    func getCommentStyle(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()

        switch ext {
            case "swift", "go", "java", "js", "ts", "tsx", "cpp", "c", "h", "cs", "kt", "m", "mm", "scala", "rs", "dart":
                return "//"
            case "py", "rb", "pl", "sh", "bash", "yml", "yaml", "conf", "toml", "r":
                return "#"
            case "html", "xml", "vue", "svelte", "md", "txt": 
                return "#"
            case "css", "scss", "less": 
                return "//"
            case "sql", "lua":
                return "--"
            case "bat", "cmd":
                return "REM"
            case "vb", "vbs":
                return "'"
            default: 
                return "#"
        }
    }

    func isTextFile(_ path: String) -> Bool {
        let knownTextExtensions = allowedExtensions.union(["txt", "md", "json", "xml", "yaml", "yml", "conf", "ini", "csv", "log", "plist", "strings", "markdown", "gitignore", "editorconfig", "gitattributes", "gitmodules", "npmignore", "dockerfile", "gradle", "properties", "rst", "tex", "latex", "bib", "tsv"])
        let ext = (path as NSString).pathExtension.lowercased()
        if knownTextExtensions.contains(ext) {
            return true
        }

        let knownBinaryExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "ico", "icns",
                                                 "mp3", "wav", "aac", "m4a", "ogg", "flac",
                                                 "mp4", "mov", "avi", "mkv", "wmv", "flv",
                                                 "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
                                                 "zip", "gz", "tar", "rar", "7z", "bz2", "dmg", "iso",
                                                 "app", "exe", "dll", "so", "dylib", "o", "a", "lib",
                                                 "class", "jar", "pyc", "pyd", "bin", "dat", "data",
                                                 "db", "sqlite", "mdb", "accdb", "ttf", "otf", "woff", "woff2",
                                                 "eot", "psd", "ai", "eps", "svg", 
                                                 "dylib", "bundle", "framework"]

        if knownBinaryExtensions.contains(ext) {
            return false
        }

        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return false 
        }
        defer { fileHandle.closeFile() }

        let data: Data
        if #available(macOS 10.15.4, *) {
            guard let readData = try? fileHandle.read(upToCount: 4096) else {
                return false 
            }
            data = readData
        } else {
            data = fileHandle.readData(ofLength: 4096)
        }

        if data.isEmpty {
            return true 
        }

        if data.contains(0) {
            return false 
        }

        if String(data: data, encoding: .utf8) == nil {
             if String(data: data, encoding: .isoLatin1) != nil || String(data: data, encoding: .windowsCP1252) != nil {
                 return true
             }
            return false 
        }

        return true
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil) 
    }
}