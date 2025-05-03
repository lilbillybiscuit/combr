import Cocoa

class FileItem: NSObject {
    let path: String
    let isDirectory: Bool
    var children: [FileItem]?
    weak var parent: FileItem?
    
    var isSelected: Bool = false {
        didSet {
            if oldValue != isSelected {
                updateParentSelectionState()
            }
        }
    }

    var selectionState: NSControl.StateValue {
        if isDirectory {
            guard let children = children, !children.isEmpty else { 
                return isSelected ? .on : .off 
            }

            var hasSelectedChild = false
            var hasUnselectedChild = false
            
            for child in children {
                if child.isDirectory {
                    let childState = child.selectionState
                    if childState == .on || childState == .mixed {
                        hasSelectedChild = true
                    } else {
                        hasUnselectedChild = true
                    }
                } else {
                    if child.isSelected {
                        hasSelectedChild = true
                    } else {
                        hasUnselectedChild = true
                    }
                }
                
                if hasSelectedChild && hasUnselectedChild {
                    break
                }
            }
            
            if hasSelectedChild && hasUnselectedChild {
                return .mixed
            } else if hasSelectedChild {
                return .on
            } else {
                return isSelected ? .on : .off
            }
        }
        
        return isSelected ? .on : .off
    }
    
    private func updateParentSelectionState() {
        guard let parent = parent, parent.isDirectory else { return }
        
        let newState = calculateParentState(for: parent)
        
        if parent.isSelected != newState {
            let oldParentDidSetEnabled = parent.disableDidSet
            parent.disableDidSet = true
            parent.isSelected = newState
            parent.disableDidSet = oldParentDidSetEnabled
            
            parent.updateParentSelectionState()
        }
    }
    
    private func calculateParentState(for item: FileItem) -> Bool {
        guard item.isDirectory, let children = item.children, !children.isEmpty else {
            return item.isSelected
        }
        
        let allSelected = !children.contains { !$0.isSelected }
        if allSelected {
            return true
        }
        
        let someSelected = children.contains { $0.isSelected }
        if someSelected {
            return true
        }
        
        return false
    }
    
    private var disableDidSet: Bool = false

    init(path: String, isDirectory: Bool, processor: FileProcessor, parent: FileItem? = nil) {
        self.path = path
        self.isDirectory = isDirectory
        self.parent = parent
        super.init()

        if !isDirectory {
            self.isSelected = processor.shouldAutoSelectFile(path)
        }
    }

    convenience init?(path: String, processor: FileProcessor, parent: FileItem? = nil) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
             return nil
        }

        let isDirectory = isDir.boolValue
        let filename = (path as NSString).lastPathComponent

        if processor.shouldExclude(filename: filename, fullPath: path, isDirectory: isDirectory) {
            return nil
        }

        self.init(path: path, isDirectory: isDirectory, processor: processor, parent: parent)

        if isDirectory {
            self.loadChildren(processor: processor)
        }
    }

    func loadChildren(processor: FileProcessor) {
        guard isDirectory else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            children = contents
                .compactMap { childName -> FileItem? in
                    let fullPath = (path as NSString).appendingPathComponent(childName)
                    return FileItem(path: fullPath, processor: processor, parent: self)
                }
                .filter { item -> Bool in
                    if !item.isDirectory && !processor.isTextFile(item.path) {
                        return false
                    }
                    return true
                }
            children?.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        } catch {
            print("Error loading directory contents for \(path): \(error)")
            children = []
        }
    }
}