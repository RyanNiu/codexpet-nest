import AppKit

struct SidebarItem: Equatable {
    let id: String
    let title: String
    let iconName: String
    let isCategory: Bool
    
    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Notification.Name {
    static let sidebarSelectionChanged = Notification.Name("sidebarSelectionChanged")
}

final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let settingsButton = NSButton()
    
    private var menuItems: [SidebarItem] = [
        SidebarItem(id: "marketplace", title: "Marketplace", iconName: "bag", isCategory: false),
        SidebarItem(id: "myPets", title: "My Pets", iconName: "pawprint", isCategory: false),
        SidebarItem(id: "nestManager", title: "Nest Manager", iconName: "house", isCategory: false)
    ]
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NestUI.sidebarBackground.cgColor
        
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = false // Hide vertical scroller
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.selectionHighlightStyle = .regular
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        outlineView.addTableColumn(column)
        
        // Settings Button
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked(_:))
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.contentTintColor = .secondaryLabelColor
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: settingsButton.topAnchor, constant: -12),
            
            settingsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            settingsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 24),
            settingsButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        outlineView.reloadData()
        outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }
    
    @objc private func settingsClicked(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "升级", action: #selector(upgradeClicked), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        let versionItem = NSMenuItem(title: "版本 \(AppVersion.fullVersionString)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: l("menu.quit"), action: #selector(quitClicked), keyEquivalent: "q")
        
        let p = NSPoint(x: 0, y: sender.frame.height + 5)
        menu.popUp(positioning: nil, at: p, in: sender)
    }
    
    @objc private func upgradeClicked() {
        if let url = URL(string: "https://codexpet.xyz") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
    
    // MARK: - NSOutlineViewDataSource
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return menuItems.count }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return menuItems[index] }
        return "" // Not reachable as isItemExpandable is false
    }
    
    // MARK: - NSOutlineViewDelegate
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let sidebarItem = item as? SidebarItem else { return nil }
        
        let identifier = NSUserInterfaceItemIdentifier("ItemCell")
        var view = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if view == nil {
            view = NSTableCellView()
            view?.identifier = identifier
            
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            view?.addSubview(imageView)
            view?.imageView = imageView
            
            let textField = NSTextField(labelWithString: "")
            textField.font = .systemFont(ofSize: 13, weight: .regular)
            textField.translatesAutoresizingMaskIntoConstraints = false
            view?.addSubview(textField)
            view?.textField = textField
            
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: view!.leadingAnchor, constant: 8),
                imageView.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 18),
                imageView.heightAnchor.constraint(equalToConstant: 18),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
                textField.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: view!.trailingAnchor, constant: -8)
            ])
        }
        
        view?.textField?.stringValue = sidebarItem.title
        view?.textField?.textColor = .labelColor
        
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let image = NSImage(systemSymbolName: sidebarItem.iconName, accessibilityDescription: nil) {
            view?.imageView?.image = image.withSymbolConfiguration(config)
        }
        
        view?.imageView?.contentTintColor = .secondaryLabelColor
        
        return view

    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 36
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0 else { return }
        let item = menuItems[row]
        NotificationCenter.default.post(name: .sidebarSelectionChanged, object: nil, userInfo: ["item": item])
    }
    
    func selectItem(withId id: String) {
        guard let index = menuItems.firstIndex(where: { $0.id == id }) else { return }
        if outlineView.selectedRow != index {
            outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
    }
}
