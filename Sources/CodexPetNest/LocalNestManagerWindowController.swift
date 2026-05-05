import AppKit

final class LocalNestManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = LocalNestManagerWindowController()
    
    private var tableView: NSTableView!
    private var nests: [InstalledNest] = []
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Manage Local Nests"
        window.center()
        super.init(window: window)
        setupUI()
        refreshData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: .installedNestsChanged, object: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshData()
    }
    
    private func setupUI() {
        let scrollView = NSScrollView(frame: window!.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NestColumn"))
        column.width = tableView.bounds.width
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        window?.contentView?.addSubview(scrollView)
        
        // Toolbar or Buttons
        let bottomBar = NSStackView(frame: NSRect(x: 20, y: 10, width: 560, height: 30))
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.alignment = .centerY
        
        let installBtn = NSButton(title: "Install Local Nest ZIP...", target: self, action: #selector(installLocalNest))
        let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(refreshData))
        
        bottomBar.addArrangedSubview(installBtn)
        bottomBar.addArrangedSubview(refreshBtn)
        bottomBar.addArrangedSubview(NSView()) // Spacer
        
        window?.contentView?.addSubview(bottomBar)
        
        // Adjust scrollView frame to leave space for bottomBar
        scrollView.frame = NSRect(x: 0, y: 50, width: 600, height: 350)
    }
    
    @objc private func refreshData() {
        self.nests = LocalNestManager.shared.installedNests
        tableView.reloadData()
    }
    
    // MARK: - TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return nests.count + 2 // +2 for "Default" and "Capacity Orbit"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = NSTableCellView()
        view.identifier = NSUserInterfaceItemIdentifier("NestCell")
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5)
        ])
        
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 4
        iconView.layer?.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 60).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 45).isActive = true
        stack.addArrangedSubview(iconView)
        
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 2
        stack.addArrangedSubview(infoStack)
        
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        infoStack.addArrangedSubview(titleLabel)
        
        let authorLabel = NSTextField(labelWithString: "")
        authorLabel.font = NSFont.systemFont(ofSize: 11)
        authorLabel.textColor = .secondaryLabelColor
        infoStack.addArrangedSubview(authorLabel)
        
        let spacer = NSView()
        stack.addArrangedSubview(spacer)
        
        let activeLabel = NSTextField(labelWithString: "Active")
        activeLabel.font = NSFont.boldSystemFont(ofSize: 11)
        activeLabel.textColor = .systemGreen
        activeLabel.isHidden = true
        stack.addArrangedSubview(activeLabel)
        
        let useBtn = NSButton(title: "Use", target: self, action: #selector(useNest(_:)))
        useBtn.bezelStyle = .rounded
        stack.addArrangedSubview(useBtn)
        
        let menuBtn = NSButton(image: NSImage(named: NSImage.actionTemplateName)!, target: self, action: #selector(showMenu(_:)))
        menuBtn.bezelStyle = .recessed
        menuBtn.isBordered = false
        stack.addArrangedSubview(menuBtn)
        
        let currentNestId = SettingsStore.shared.settings.activeNestId
        
        if row == 0 {
            titleLabel.stringValue = "Classic Nest"
            authorLabel.stringValue = "Built-in / Default"
            iconView.image = NSImage(named: NSImage.applicationIconName)
            useBtn.tag = -1
            menuBtn.tag = -1
            menuBtn.isEnabled = false
            if currentNestId == "default" {
                activeLabel.isHidden = false
                useBtn.isEnabled = false
            }
        } else if row == 1 {
            titleLabel.stringValue = "Capacity Orbit"
            authorLabel.stringValue = "Built-in • Shows live usage rings around your pet"
            iconView.image = NSImage(named: NSImage.networkName)
            useBtn.tag = -2
            menuBtn.tag = -2
            menuBtn.isEnabled = false
            if currentNestId == "capacity-orbit-nest" {
                activeLabel.isHidden = false
                useBtn.isEnabled = false
            }
        } else {
            let nest = nests[row - 2]
            titleLabel.stringValue = nest.name
            authorLabel.stringValue = "v\(nest.version) by \(nest.author)"
            if let pURL = nest.previewURL {
                iconView.image = NSImage(contentsOf: pURL)
            } else {
                iconView.image = NSImage(named: NSImage.networkName)
            }
            useBtn.tag = row - 2
            menuBtn.tag = row - 2
            if currentNestId == nest.id {
                activeLabel.isHidden = false
                useBtn.isEnabled = false
            }
        }
        
        return view
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 60
    }
    
    // MARK: - Actions
    
    @objc private func useNest(_ sender: NSButton) {
        let id: String
        if sender.tag == -1 {
            id = "default"
        } else if sender.tag == -2 {
            id = "capacity-orbit-nest"
        } else {
            id = nests[sender.tag].id
        }
        LocalNestManager.shared.applyNest(id: id)
        tableView.reloadData()
    }
    
    @objc private func showMenu(_ sender: NSButton) {
        guard sender.tag >= 0 else { return }
        let nest = nests[sender.tag]
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Open in Finder", action: #selector(openInFinder(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Uninstall", action: #selector(uninstallNest(_:)), keyEquivalent: "").target = self
        
        menu.item(at: 0)?.representedObject = nest
        menu.item(at: 1)?.representedObject = nest
        
        let point = NSPoint(x: 0, y: sender.bounds.height)
        menu.popUp(positioning: nil, at: point, in: sender)
    }
    
    @objc private func openInFinder(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        LocalNestManager.shared.openNestFolder(id: nest.id)
    }
    
    @objc private func uninstallNest(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        
        let alert = NSAlert()
        alert.messageText = "Uninstall Nest Skin?"
        alert.informativeText = "Are you sure you want to remove '\(nest.name)'? This cannot be undone."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try LocalNestManager.shared.uninstallNest(id: nest.id)
            } catch {
                let errAlert = NSAlert(error: error)
                errAlert.runModal()
            }
        }
    }
    
    @objc private func installLocalNest() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await PackageManager.shared.installLocalNest(zipURL: url)
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Nest Installed"
                        alert.informativeText = "The nest skin has been installed successfully. Would you like to use it now?"
                        alert.addButton(withTitle: "Apply Now")
                        alert.addButton(withTitle: "Later")
                        if alert.runModal() == .alertFirstButtonReturn {
                            // Find the newly installed nest
                            LocalNestManager.shared.refresh()
                            if let newNest = LocalNestManager.shared.installedNests.last {
                                LocalNestManager.shared.applyNest(id: newNest.id)
                            }
                        }
                        self.refreshData()
                    }
                } catch {
                    await MainActor.run {
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    }
                }
            }
        }
    }
}
