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
        window.title = "Configure Quick Actions"
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

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        let bottomBar = NSStackView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.alignment = .centerY

        let addBtn = NSButton(title: "+", target: self, action: #selector(addAction))
        addBtn.bezelStyle = .rounded

        let editBtn = NSButton(title: "Edit", target: self, action: #selector(editAction))
        let deleteBtn = NSButton(title: "Delete", target: self, action: #selector(deleteAction))
        let upBtn = NSButton(title: "Up", target: self, action: #selector(moveActionUp))
        let downBtn = NSButton(title: "Down", target: self, action: #selector(moveActionDown))

        let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(refreshFromStore))

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
            iconView.contentTintColor = .white
        }

        let nameLabel = NSTextField(labelWithString: action.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .white

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
        let row = tableView.clickedRow
        guard row >= 0, row < actions.count else { return }
        presentEditSheet(for: actions[row])
    }

    @objc private func deleteAction() {
        let row = tableView.clickedRow
        guard row >= 0, row < actions.count else { return }
        let action = actions[row]
        QuickActionConfigStore.shared.delete(id: action.id, nestId: nestId)
        refreshData()
        postRefreshNotification()
    }

    @objc private func moveActionUp() {
        let row = tableView.clickedRow
        guard row > 0, row < actions.count else { return }
        swapOrder(row, row - 1)
    }

    @objc private func moveActionDown() {
        let row = tableView.clickedRow
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        sheet.title = existing == nil ? "Add Quick Action" : "Edit Quick Action"

        let isNew = existing == nil
        let editAction = existing ?? QuickActionConfig(
            nestId: nestId,
            name: "",
            icon: "bolt.fill",
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
    private var kindPopup: NSPopUpButton!
    private var targetField: NSTextField!
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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 320))
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
        let nameRow = makeRow(label: "Name")
        nameField = makeTextField(placeholder: "E.g. Open Terminal")
        nameField.stringValue = action.name
        nameRow.addArrangedSubview(nameField)
        formStack.addArrangedSubview(nameRow)

        // Icon
        let iconRow = makeRow(label: "Icon")
        iconField = makeTextField(placeholder: "SF Symbol name, e.g. terminal.fill")
        iconField.stringValue = action.icon
        iconRow.addArrangedSubview(iconField)
        formStack.addArrangedSubview(iconRow)

        // Kind
        let kindRow = makeRow(label: "Kind")
        kindPopup = NSPopUpButton()
        kindPopup.translatesAutoresizingMaskIntoConstraints = false
        kindPopup.addItems(withTitles: QuickActionKind.allCases.map { $0.rawValue.capitalized })
        if let idx = QuickActionKind.allCases.firstIndex(of: action.kind) {
            kindPopup.selectItem(at: idx)
        }
        kindRow.addArrangedSubview(kindPopup)
        formStack.addArrangedSubview(kindRow)

        // Target
        let targetRow = makeRow(label: "Target")
        targetField = makeTextField(placeholder: "/Applications/App.app, shortcut name, or shell command")
        targetField.stringValue = action.target
        targetRow.addArrangedSubview(targetField)
        formStack.addArrangedSubview(targetRow)

        // Confirm
        let confirmRow = makeRow(label: "")
        confirmCheckbox = NSButton(checkboxWithTitle: "Require confirmation (terminal only)", target: nil, action: nil)
        confirmCheckbox.translatesAutoresizingMaskIntoConstraints = false
        confirmCheckbox.state = action.requiresConfirmation ? .on : .off
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

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let saveBtn = NSButton(title: isNew ? "Add" : "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
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
            targetField.widthAnchor.constraint(equalToConstant: 260),

            btnRow.widthAnchor.constraint(equalTo: formStack.widthAnchor)
        ])
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

    private func makeTextField(placeholder: String) -> NSTextField {
        let tf = NSTextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholderString = placeholder
        tf.font = .systemFont(ofSize: 13)
        return tf
    }

    @objc private func cancel() {
        view.window?.sheetParent?.endSheet(sheet)
    }

    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let icon = iconField.stringValue.trimmingCharacters(in: .whitespaces)
        let target = targetField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            showError("Name is required.")
            return
        }
        guard !icon.isEmpty else {
            showError("Icon is required.")
            return
        }
        guard NSImage(systemSymbolName: icon, accessibilityDescription: name) != nil else {
            showError("Invalid SF Symbol name: \(icon)")
            return
        }
        guard !target.isEmpty else {
            showError("Target is required.")
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

extension Notification.Name {
    static let refreshQuickActions = Notification.Name("refreshQuickActions")
}
