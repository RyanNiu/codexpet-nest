import AppKit

final class MainContentViewController: NSViewController {
    
    private let contentContainer = NSView()
    private var currentContentVC: NSViewController?
    
    // View Controllers to cache
    private lazy var onlineMarketplaceVC = OnlinePetMarketplaceViewController()
    private lazy var localPetManagerVC = LocalPetManagerViewController()
    private lazy var localNestManagerVC = LocalNestManagerViewController()
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func switchTo(item: SidebarItem) {
        let newVC: NSViewController
        
        switch item.id {
        case "marketplace", "allPets":
            newVC = onlineMarketplaceVC
        case "myPets", "installed":
            newVC = localPetManagerVC
        case "nestManager":
            newVC = localNestManagerVC
        default:
            // Fallback for others currently
            newVC = onlineMarketplaceVC
        }
        
        if currentContentVC == newVC { return }
        
        currentContentVC?.view.removeFromSuperview()
        currentContentVC?.removeFromParent()
        
        addChild(newVC)
        newVC.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(newVC.view)
        
        NSLayoutConstraint.activate([
            newVC.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            newVC.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        currentContentVC = newVC
    }
}
