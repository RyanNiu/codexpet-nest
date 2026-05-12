import AppKit

final class LocalNestManagerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = LocalNestManagerViewController()
    
    private var tableView: NSTableView!
    private var nests: [InstalledNest] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshData()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: .installedNestsChanged, object: nil)
    }
    
    override func loadView() {
        self.view = NSView()
    }
    
    private func setupUI() {
        let contentView = self.view
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        NestUI.panel(scrollView)
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 82
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
        tableView.selectionHighlightStyle = .regular
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NestColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        let bottomBar = NSStackView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.alignment = .centerY
        
        let installBtn = NSButton(title: l("manage.install_local_nest"), target: self, action: #selector(installLocalNest))
        let refreshBtn = NSButton(title: l("manage.refresh"), target: self, action: #selector(refreshData))
        NestUI.stylePrimaryButton(installBtn)
        NestUI.styleSecondaryButton(refreshBtn)
        
        bottomBar.addArrangedSubview(installBtn)
        bottomBar.addArrangedSubview(refreshBtn)
        bottomBar.addArrangedSubview(NSView()) // Spacer
        
        contentView.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            bottomBar.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func refreshData() {
        self.nests = LocalNestManager.shared.installedNests
        tableView.reloadData()
    }
    
    // MARK: - TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return nests.count + 1 // +1 for "Capacity Orbit"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = NSTableCellView()
        view.identifier = NSUserInterfaceItemIdentifier("NestCell")
        NestUI.panel(view, color: .controlBackgroundColor)

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        iconView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        iconView.layer?.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)
        
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 4
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoStack)
        
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        infoStack.addArrangedSubview(titleLabel)
        
        let authorLabel = NSTextField(labelWithString: "")
        authorLabel.font = NSFont.systemFont(ofSize: 11)
        authorLabel.textColor = .secondaryLabelColor
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 2
        infoStack.addArrangedSubview(authorLabel)

        let badgeStack = NSStackView()
        badgeStack.orientation = .horizontal
        badgeStack.spacing = 6
        badgeStack.alignment = .centerY
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.addArrangedSubview(badgeStack)

        let activeBadge = NestUI.badge(l("manage.active"), color: .systemGreen)
        let sourceBadge = NestUI.badge("", color: .systemBlue)
        badgeStack.addArrangedSubview(activeBadge)
        badgeStack.addArrangedSubview(sourceBadge)

        let useBtn = NSButton(title: l("manage.use"), target: self, action: #selector(useNest(_:)))
        NestUI.styleSecondaryButton(useBtn)
        useBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(useBtn)
        
        let menuBtn = NSButton(image: NSImage(named: NSImage.actionTemplateName)!, target: self, action: #selector(showMenu(_:)))
        menuBtn.bezelStyle = .recessed
        menuBtn.isBordered = false
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuBtn)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            infoStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            infoStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: useBtn.leadingAnchor, constant: -16),

            useBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            useBtn.widthAnchor.constraint(equalToConstant: 72),
            useBtn.trailingAnchor.constraint(equalTo: menuBtn.leadingAnchor, constant: -8),

            menuBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            menuBtn.widthAnchor.constraint(equalToConstant: 28),
            menuBtn.heightAnchor.constraint(equalToConstant: 28),
            menuBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        let currentNestId = SettingsStore.shared.settings.activeNestId
        
        if row == 0 {
            titleLabel.stringValue = l("manage.orbit_title")
            authorLabel.stringValue = l("manage.orbit_desc")
            iconView.image = NSImage(named: NSImage.networkName)
            sourceBadge.stringValue = "Built-in"
            useBtn.tag = -2
            menuBtn.tag = -2
            menuBtn.isEnabled = false
            if currentNestId == "capacity-orbit-nest" {
                activeBadge.isHidden = false
                useBtn.isEnabled = false
            } else {
                activeBadge.isHidden = true
            }
        } else {
            let nest = nests[row - 1]
            titleLabel.stringValue = nest.name
            
            if nest.isBuiltIn {
                authorLabel.stringValue = "Built-in • v\(nest.version) by \(nest.author)"
            } else {
                authorLabel.stringValue = "v\(nest.version) by \(nest.author)"
            }
            sourceBadge.stringValue = nest.isBuiltIn ? "Built-in" : "Local"
            sourceBadge.textColor = nest.isBuiltIn ? .systemTeal : .systemBlue
            sourceBadge.layer?.backgroundColor = (sourceBadge.textColor ?? .systemBlue).withAlphaComponent(0.12).cgColor
            
            if let pURL = nest.previewURL {
                iconView.image = NSImage(contentsOf: pURL)
            } else {
                iconView.image = NSImage(named: NSImage.networkName)
            }
            useBtn.tag = row - 1
            menuBtn.tag = row - 1
            if currentNestId == nest.id {
                activeBadge.isHidden = false
                useBtn.isEnabled = false
            } else {
                activeBadge.isHidden = true
            }
        }
        
        return view
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 82
    }
    
    // MARK: - Actions
    
    @objc private func useNest(_ sender: NSButton) {
        let id: String
        if sender.tag == -2 {
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

        if QuickActionConfigStore.shared.hasComponent(nestId: nest.id) {
            let qaItem = NSMenuItem(title: l("menu.configure_quick_actions"), action: #selector(configureQuickActions(_:)), keyEquivalent: "")
            qaItem.target = self
            qaItem.representedObject = nest
            menu.addItem(qaItem)
            menu.addItem(.separator())
        }

        let hoverItem = NSMenuItem(title: l("manage.hover_only"), action: #selector(toggleHoverOnly(_:)), keyEquivalent: "")
        hoverItem.target = self
        hoverItem.representedObject = nest
        hoverItem.state = SettingsStore.shared.settings.hoverOnlyNestIds.contains(nest.id) ? .on : .off
        menu.addItem(hoverItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: l("manage.open_in_finder"), action: #selector(openInFinder(_:)), keyEquivalent: "").target = self

        let uninstallItem = NSMenuItem(title: l("manage.uninstall"), action: #selector(uninstallNest(_:)), keyEquivalent: "")
        uninstallItem.target = self
        uninstallItem.isEnabled = !nest.isBuiltIn
        menu.addItem(uninstallItem)

        menu.item(at: 0)?.representedObject = nest
        uninstallItem.representedObject = nest

        let point = NSPoint(x: 0, y: sender.bounds.height)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func configureQuickActions(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        QuickActionsConfigWindowController.shared.show(for: nest.id)
    }

    @objc private func toggleHoverOnly(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        var hoverSet = SettingsStore.shared.settings.hoverOnlyNestIds
        if hoverSet.contains(nest.id) {
            hoverSet.remove(nest.id)
        } else {
            hoverSet.insert(nest.id)
        }
        SettingsStore.shared.settings.hoverOnlyNestIds = hoverSet
        SettingsStore.shared.save()
        tableView.reloadData()
    }
    
    @objc private func openInFinder(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        LocalNestManager.shared.openNestFolder(id: nest.id)
    }
    
    @objc private func uninstallNest(_ sender: NSMenuItem) {
        guard let nest = sender.representedObject as? InstalledNest else { return }
        
        let alert = NSAlert()
        alert.messageText = l("manage.uninstall_confirm_title")
        alert.informativeText = l("manage.uninstall_confirm_message", nest.name)
        alert.addButton(withTitle: l("manage.uninstall"))
        alert.addButton(withTitle: l("manage.later")) // Using later as cancel for simplicity, or add cancel
        
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
                        alert.messageText = l("manage.install_success_title")
                        alert.informativeText = l("manage.install_success_message")
                        alert.addButton(withTitle: l("manage.apply_now"))
                        alert.addButton(withTitle: l("manage.later"))
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
