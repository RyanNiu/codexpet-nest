import AppKit

final class MainWindowController: NSWindowController {
    static let shared = MainWindowController()
    
    private let splitViewController = NSSplitViewController()
    private let sidebarVC = SidebarViewController()
    private let contentVC = MainContentViewController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexPet Nest"
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        
        // Modern window styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Window background
        window.backgroundColor = NSColor.windowBackgroundColor
        
        super.init(window: window)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarSelection(_:)), name: .sidebarSelectionChanged, object: nil)
        
        setupSplitView()
        window.contentViewController = splitViewController
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupSplitView() {
        // Sidebar Item
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 280
        sidebarItem.canCollapse = true
        
        // Content Item
        let contentItem = NSSplitViewItem(viewController: contentVC)
        
        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func handleSidebarSelection(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? SidebarItem else { return }
        contentVC.switchTo(item: item)
        sidebarVC.selectItem(withId: item.id)
    }
}
