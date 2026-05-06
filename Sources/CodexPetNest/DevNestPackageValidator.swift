import Foundation

#if DEBUG
final class DevNestPackageValidator {
    static func runValidation(fixturesDir: URL) async -> Bool {
        print("[DevValidator] Starting v1.1 Nest Theme validation...")
        
        let themes = ["basket-pomodoro-nest", "legend-status-nest", "trainer-card-nest", "window-desk-nest"]
        let manager = PackageManager.shared
        let originalActiveId = SettingsStore.shared.settings.activeNestId
        var overallSuccess = true
        
        for theme in themes {
            let zipURL = fixturesDir.appendingPathComponent("\(theme).zip")
            
            // Step 1: Zip Exists
            if !FileManager.default.fileExists(atPath: zipURL.path) {
                print("[DevValidator] ✗ \(theme).zip NOT found at \(zipURL.path)")
                overallSuccess = false
                continue
            }
            print("[DevValidator] ✓ \(theme).zip exists")
            
            do {
                // Step 2: Install
                try await manager.installLocalNest(zipURL: zipURL)
                print("[DevValidator] ✓ \(theme) installed successfully")
                
                // Step 3: Manager recognition
                LocalNestManager.shared.refresh()
                let installed = LocalNestManager.shared.installedNests
                guard let nest = installed.first(where: { $0.id == theme }) else {
                    print("[DevValidator] ✗ \(theme) NOT recognized by LocalNestManager after install")
                    overallSuccess = false
                    continue
                }
                print("[DevValidator] ✓ \(theme) recognized by LocalNestManager")
                
                // Step 4: Renderer initialization
                print("[DevValidator] Running static smoke test for \(theme)...")
                SettingsStore.shared.settings.activeNestId = theme
                
                let renderer = await MainActor.run {
                    return NestRenderer(frame: NSRect(x: 0, y: 0, width: nest.layout.canvas.width, height: nest.layout.canvas.height))
                }
                
                await MainActor.run {
                    renderer.layout() // Trigger layout
                }
                print("[DevValidator] ✓ \(theme) renderer initialized and layouted")
                
            } catch {
                print("[DevValidator] ✗ \(theme) validation failed: \(error.localizedDescription)")
                overallSuccess = false
            }
        }
        
        // Restore original state
        SettingsStore.shared.settings.activeNestId = originalActiveId
        SettingsStore.shared.save()
        LocalNestManager.shared.refresh()
        
        if overallSuccess {
            print("[DevValidator] PASS: All v1.1 themes validated successfully.")
        } else {
            print("[DevValidator] FAIL: One or more v1.1 themes failed validation.")
        }
        
        return overallSuccess
    }
}
#endif
