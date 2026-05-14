import AppKit

final class QuickActionsConfigWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    static let shared = QuickActionsConfigWindowController()

    private var tableView: NSTableView!
    private var actions: [QuickActionConfig] = []
    private var nestId: String = ""

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = l("qa.title")
        window.center()
        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(for nestId: String) {
        self.nestId = nestId
        refreshData()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshData() {
        actions = QuickActionConfigStore.shared.actions(for: nestId)
        tableView.reloadData()
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NestUI.contentBackground.cgColor


        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.doubleAction = #selector(editAction)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("QA"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.registerForDraggedTypes([.quickActionRow])

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        let bottomBar = NSStackView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.alignment = .centerY

        let addBtn = NSButton(title: l("qa.add"), target: self, action: #selector(addAction))
        let editBtn = NSButton(title: l("qa.edit"), target: self, action: #selector(editAction))
        let deleteBtn = NSButton(title: l("qa.delete"), target: self, action: #selector(deleteAction))
        let upBtn = NSButton(title: l("qa.up"), target: self, action: #selector(moveActionUp))
        let downBtn = NSButton(title: l("qa.down"), target: self, action: #selector(moveActionDown))
        let refreshBtn = NSButton(title: l("manage.refresh"), target: self, action: #selector(refreshFromStore))

        NestUI.stylePrimaryButton(addBtn)
        NestUI.styleSecondaryButton(editBtn)
        NestUI.styleSecondaryButton(deleteBtn)
        NestUI.styleSecondaryButton(upBtn)
        NestUI.styleSecondaryButton(downBtn)
        NestUI.styleSecondaryButton(refreshBtn)


        bottomBar.addArrangedSubview(addBtn)
        bottomBar.addArrangedSubview(editBtn)
        bottomBar.addArrangedSubview(deleteBtn)
        bottomBar.addArrangedSubview(upBtn)
        bottomBar.addArrangedSubview(downBtn)
        bottomBar.addArrangedSubview(refreshBtn)
        bottomBar.addArrangedSubview(NSView())

        contentView.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            bottomBar.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { actions.count }

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false)
        pboard.declareTypes([.quickActionRow], owner: self)
        pboard.setData(data, forType: .quickActionRow)
        return true
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard dropOperation == .above else { return [] }
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let data = info.draggingPasteboard.data(forType: .quickActionRow),
              let rowIndexes = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSIndexSet.self, from: data) as? IndexSet,
              let fromRow = rowIndexes.first else {
            return false
        }

        var toRow = row
        if fromRow < toRow {
            toRow -= 1 // Adjust insertion index if moving downwards
        }

        guard fromRow != toRow else { return false }

        let store = QuickActionConfigStore.shared
        let actionToMove = actions.remove(at: fromRow)
        actions.insert(actionToMove, at: toRow)

        for (index, var action) in actions.enumerated() {
            action.order = index
            store.update(action)
        }

        tableView.reloadData()
        postRefreshNotification()
        return true
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let action = actions[row]

        let cell = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 44))
        cell.wantsLayer = true

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        if let symbol = NSImage(systemSymbolName: action.icon, accessibilityDescription: action.name) {
            iconView.image = symbol
            iconView.contentTintColor = .labelColor
        }

        let nameLabel = NSTextField(labelWithString: action.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor

        let kindLabel = NSTextField(labelWithString: action.kind.rawValue.capitalized)
        kindLabel.translatesAutoresizingMaskIntoConstraints = false
        kindLabel.font = .systemFont(ofSize: 11, weight: .regular)
        kindLabel.textColor = .secondaryLabelColor

        let targetLabel = NSTextField(labelWithString: action.target)
        targetLabel.translatesAutoresizingMaskIntoConstraints = false
        targetLabel.font = .systemFont(ofSize: 11, weight: .regular)
        targetLabel.textColor = .tertiaryLabelColor
        targetLabel.lineBreakMode = .byTruncatingMiddle

        let enabledToggle = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
        enabledToggle.translatesAutoresizingMaskIntoConstraints = false
        enabledToggle.state = action.enabled ? .on : .off
        enabledToggle.tag = row

        cell.addSubview(iconView)
        cell.addSubview(nameLabel)
        cell.addSubview(kindLabel)
        cell.addSubview(targetLabel)
        cell.addSubview(enabledToggle)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),

            kindLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            kindLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            targetLabel.leadingAnchor.constraint(equalTo: kindLabel.trailingAnchor, constant: 8),
            targetLabel.centerYAnchor.constraint(equalTo: kindLabel.centerYAnchor),
            targetLabel.trailingAnchor.constraint(equalTo: enabledToggle.leadingAnchor, constant: -8),

            enabledToggle.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            enabledToggle.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            enabledToggle.widthAnchor.constraint(equalToConstant: 24)
        ])

        return cell
    }

    // MARK: - Actions

    @objc private func addAction() {
        presentEditSheet(for: nil)
    }

    @objc private func editAction() {
        let row = tableView.selectedRow
        guard row >= 0, row < actions.count else { return }
        presentEditSheet(for: actions[row])
    }

    @objc private func deleteAction() {
        let row = tableView.selectedRow
        guard row >= 0, row < actions.count else { return }
        let action = actions[row]
        QuickActionConfigStore.shared.delete(id: action.id, nestId: nestId)
        refreshData()
        postRefreshNotification()
    }

    @objc private func moveActionUp() {
        let row = tableView.selectedRow
        guard row > 0, row < actions.count else { return }
        swapOrder(row, row - 1)
    }

    @objc private func moveActionDown() {
        let row = tableView.selectedRow
        guard row >= 0, row < actions.count - 1 else { return }
        swapOrder(row, row + 1)
    }

    private func swapOrder(_ i: Int, _ j: Int) {
        let store = QuickActionConfigStore.shared
        var a = actions[i]
        var b = actions[j]
        swap(&a.order, &b.order)
        store.update(a)
        store.update(b)
        actions = store.actions(for: nestId)
        tableView.reloadData()
        postRefreshNotification()
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < actions.count else { return }
        var action = actions[row]
        action.enabled = (sender.state == .on)
        QuickActionConfigStore.shared.update(action)
        postRefreshNotification()
    }

    @objc private func refreshFromStore() {
        refreshData()
    }

    private func postRefreshNotification() {
        NotificationCenter.default.post(name: .refreshQuickActions, object: nestId)
    }

    // MARK: - Edit Sheet

    private func presentEditSheet(for existing: QuickActionConfig?) {
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        sheet.title = existing == nil ? l("qa.add_title") : l("qa.edit_title")

        let isNew = existing == nil
        let editAction = existing ?? QuickActionConfig(
            nestId: nestId,
            name: "",
            icon: "app.fill",
            kind: .app,
            target: "",
            enabled: true,
            order: actions.count
        )

        let form = QuickActionEditForm(action: editAction, isNew: isNew, sheet: sheet) { [weak self] savedAction in
            let store = QuickActionConfigStore.shared
            if isNew {
                store.add(savedAction)
            } else {
                store.update(savedAction)
            }
            self?.refreshData()
            self?.postRefreshNotification()
        }

        sheet.contentViewController = form
        window?.beginSheet(sheet)
    }
}

// MARK: - Edit Form

final class QuickActionEditForm: NSViewController, NSTextFieldDelegate {

    private let action: QuickActionConfig
    private let isNew: Bool
    private let onSave: (QuickActionConfig) -> Void
    private let sheet: NSWindow

    private var nameField: NSTextField!
    private var iconField: NSTextField!
    private var iconButtons: [NSButton] = []
    private var kindPopup: NSPopUpButton!
    private var targetField: DropTargetTextField!
    private var browseBtn: NSButton!
    private var confirmRow: NSStackView!
    private var confirmCheckbox: NSButton!
    private var errorLabel: NSTextField!

    init(action: QuickActionConfig, isNew: Bool, sheet: NSWindow, onSave: @escaping (QuickActionConfig) -> Void) {
        self.action = action
        self.isNew = isNew
        self.sheet = sheet
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
        view.autoresizingMask = [.width, .height]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 12
        formStack.alignment = .leading
        formStack.translatesAutoresizingMaskIntoConstraints = false

        // Name
        let nameRow = makeRow(label: l("qa.name"))
        nameField = makeTextField(placeholder: "E.g. Open Terminal")
        nameField.stringValue = action.name
        nameRow.addArrangedSubview(nameField)
        formStack.addArrangedSubview(nameRow)

        // Icon
        let iconRow = makeRow(label: l("qa.icon"))
        iconField = makeTextField(placeholder: "SF Symbol name, e.g. terminal.fill")
        iconField.stringValue = action.icon
        iconField.delegate = self
        iconRow.addArrangedSubview(iconField)
        formStack.addArrangedSubview(iconRow)

        let iconPickerRow = makeRow(label: "")
        let iconPicker = makeIconPicker()
        iconPickerRow.addArrangedSubview(iconPicker)
        formStack.addArrangedSubview(iconPickerRow)

        // Kind
        let kindRow = makeRow(label: l("qa.kind"))
        kindPopup = NSPopUpButton()
        kindPopup.translatesAutoresizingMaskIntoConstraints = false
        kindPopup.addItems(withTitles: QuickActionKind.allCases.map { $0.rawValue.capitalized })
        if let idx = QuickActionKind.allCases.firstIndex(of: action.kind) {
            kindPopup.selectItem(at: idx)
        }
        kindPopup.target = self
        kindPopup.action = #selector(kindChanged)
        kindRow.addArrangedSubview(kindPopup)
        formStack.addArrangedSubview(kindRow)

        // Target
        let targetRow = makeRow(label: l("qa.target"))
        targetField = DropTargetTextField()
        targetField.translatesAutoresizingMaskIntoConstraints = false
        targetField.font = .systemFont(ofSize: 13)
        targetField.isEditable = true
        targetField.isSelectable = true
        targetField.stringValue = action.target
        targetField.onAppDropped = { [weak self] path in
            self?.targetField.stringValue = path
        }
        updateTargetPlaceholder()
        targetRow.addArrangedSubview(targetField)

        browseBtn = NSButton(title: "Browse...", target: self, action: #selector(browseApp))
        browseBtn.translatesAutoresizingMaskIntoConstraints = false
        browseBtn.bezelStyle = .inline
        browseBtn.isHidden = (action.kind != .app)
        targetRow.addArrangedSubview(browseBtn)
        formStack.addArrangedSubview(targetRow)

        // Confirm
        confirmRow = makeRow(label: "")
        confirmCheckbox = NSButton(checkboxWithTitle: l("qa.require_confirm"), target: nil, action: nil)
        confirmCheckbox.translatesAutoresizingMaskIntoConstraints = false
        confirmCheckbox.state = action.requiresConfirmation ? .on : .off
        confirmRow.isHidden = (action.kind != .terminal)
        confirmRow.addArrangedSubview(confirmCheckbox)
        formStack.addArrangedSubview(confirmRow)

        // Error label
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 11, weight: .regular)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true
        formStack.addArrangedSubview(errorLabel)

        view.addSubview(formStack)

        // Buttons
        let btnRow = NSStackView()
        btnRow.orientation = .horizontal
        btnRow.spacing = 10
        btnRow.alignment = .centerY
        btnRow.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: l("cancel"), target: self, action: #selector(cancel))
        let saveBtn = NSButton(title: isNew ? l("qa.add") : l("qa.save_btn"), target: self, action: #selector(save))
        
        NestUI.styleSecondaryButton(cancelBtn)
        NestUI.stylePrimaryButton(saveBtn)
        
        saveBtn.keyEquivalent = "\r"


        btnRow.addArrangedSubview(NSView())
        btnRow.addArrangedSubview(cancelBtn)
        btnRow.addArrangedSubview(saveBtn)
        formStack.addArrangedSubview(btnRow)

        NSLayoutConstraint.activate([
            formStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            formStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),

            nameField.widthAnchor.constraint(equalToConstant: 260),
            iconField.widthAnchor.constraint(equalToConstant: 260),
            targetField.widthAnchor.constraint(equalToConstant: 180),

            btnRow.widthAnchor.constraint(equalTo: formStack.widthAnchor)
        ])

        updateSelectedIconButton()
    }

    private func updateTargetPlaceholder() {
        guard let idx = kindPopup?.indexOfSelectedItem,
              idx < QuickActionKind.allCases.count else { return }
        let kind = QuickActionKind.allCases[idx]
        switch kind {
        case .app:
            targetField.placeholderString = "/Applications/App.app or drag & drop"
        case .shortcut:
            targetField.placeholderString = "Shortcut name, e.g. My Shortcut"
        case .terminal:
            targetField.placeholderString = "Shell command, e.g. ls -la"
        case .url:
            targetField.placeholderString = "https://example.com"
        }
    }

    private func makeRow(label: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let lbl = NSTextField(labelWithString: label)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 12, weight: .medium)
        lbl.textColor = .secondaryLabelColor
        lbl.alignment = .right
        lbl.widthAnchor.constraint(equalToConstant: 80).isActive = true
        row.addArrangedSubview(lbl)

        return row
    }

    private func makeTextField(placeholder: String) -> PasteFriendlyTextField {
        let tf = PasteFriendlyTextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholderString = placeholder
        tf.font = .systemFont(ofSize: 13)
        tf.isEditable = true
        tf.isSelectable = true
        return tf
    }

    private func makeIconPicker() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 6
        container.alignment = .centerY
        container.translatesAutoresizingMaskIntoConstraints = false

        for iconName in availableIcons {
            guard let image = NSImage(systemSymbolName: iconName, accessibilityDescription: iconName) else {
                continue
            }

            let btn = NSButton(image: image, target: self, action: #selector(iconPicked(_:)))
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.bezelStyle = .regularSquare
            btn.imageScaling = .scaleProportionallyDown
            btn.toolTip = iconName
            btn.identifier = NSUserInterfaceItemIdentifier(iconName)
            btn.contentTintColor = .labelColor
            btn.setButtonType(.momentaryPushIn)
            iconButtons.append(btn)
            container.addArrangedSubview(btn)

            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: 28),
                btn.heightAnchor.constraint(equalToConstant: 26)
            ])
        }

        return container
    }

    private var availableIcons: [String] {
        [
            "app.fill",
            "terminal.fill",
            "t.circle.fill",
            "command",
            "globe",
            "link",
            "bolt.fill",
            "play.fill",
            "folder.fill",
            "doc.text.fill",
            "gearshape.fill",
            "sparkles"
        ]
    }

    @objc private func iconPicked(_ sender: NSButton) {
        guard let iconName = sender.identifier?.rawValue else { return }
        iconField.stringValue = iconName
        updateSelectedIconButton()
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField === iconField {
            updateSelectedIconButton()
        }
    }

    private func updateSelectedIconButton() {
        let selectedIcon = iconField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        for button in iconButtons {
            let isSelected = button.identifier?.rawValue == selectedIcon
            button.state = isSelected ? .on : .off
            button.contentTintColor = isSelected ? .controlAccentColor : .labelColor
        }
    }

    @objc private func kindChanged() {
        guard let idx = kindPopup?.indexOfSelectedItem,
              idx < QuickActionKind.allCases.count else { return }
        let kind = QuickActionKind.allCases[idx]
        browseBtn?.isHidden = (kind != .app)
        confirmRow?.isHidden = (kind != .terminal)
        updateTargetPlaceholder()

        let currentIcon = iconField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        if currentIcon.isEmpty || currentIcon == "bolt.fill" {
            iconField?.stringValue = defaultIcon(for: kind)
            updateSelectedIconButton()
        }
    }

    private func defaultIcon(for kind: QuickActionKind) -> String {
        switch kind {
        case .app:       return "app.fill"
        case .terminal:  return "t.circle.fill"
        case .shortcut:  return "command"
        case .url:       return "globe"
        }
    }

    @objc private func browseApp() {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.targetField.stringValue = url.path
        }
    }

    @objc private func cancel() {
        view.window?.sheetParent?.endSheet(sheet)
    }

    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let icon = iconField.stringValue.trimmingCharacters(in: .whitespaces)
        let target = targetField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            showError(l("qa.name_required"))
            return
        }
        guard !icon.isEmpty else {
            showError(l("qa.icon_required"))
            return
        }
        guard NSImage(systemSymbolName: icon, accessibilityDescription: name) != nil else {
            showError(l("qa.invalid_icon", icon))
            return
        }
        guard !target.isEmpty else {
            showError(l("qa.target_required"))
            return
        }

        let kind = QuickActionKind.allCases[kindPopup.indexOfSelectedItem]

        var savedAction = action
        savedAction.name = name
        savedAction.icon = icon
        savedAction.kind = kind
        savedAction.target = target
        savedAction.requiresConfirmation = (confirmCheckbox.state == .on)

        view.window?.sheetParent?.endSheet(sheet)
        onSave(savedAction)
    }

    private func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }
}

// MARK: - Drop Target Text Field

final class DropTargetTextField: PasteFriendlyTextField {
    var onAppDropped: ((String) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupDrop()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupDrop() {
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasAppURL(sender) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = appURL(from: sender) else { return false }
        onAppDropped?(url.path)
        return true
    }

    private func hasAppURL(_ sender: NSDraggingInfo) -> Bool {
        return appURL(from: sender) != nil
    }

    private func appURL(from sender: NSDraggingInfo) -> URL? {
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return nil }
        return url.pathExtension == "app" ? url : nil
    }
}

// MARK: - Paste Friendly Text Field

class PasteFriendlyTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch chars {
        case "x":
            activeTextEditor()?.cut(self)
            return true
        case "c":
            activeTextEditor()?.copy(self)
            return true
        case "v":
            activeTextEditor()?.paste(self)
            return true
        case "a":
            activeTextEditor()?.selectAll(self)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    private func activeTextEditor() -> NSText? {
        (window?.firstResponder as? NSText) ?? window?.fieldEditor(true, for: self)
    }
}

extension Notification.Name {
    static let refreshQuickActions = Notification.Name("refreshQuickActions")
}

extension NSPasteboard.PasteboardType {
    static let quickActionRow = NSPasteboard.PasteboardType("codexpet.quickaction.row")
}
