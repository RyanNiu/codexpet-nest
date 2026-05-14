import AppKit

@MainActor
enum PackageUI {
    static func showOverwritePrompt(name: String, id: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Pet Already Installed"
        alert.informativeText = "A pet named \"\(name)\" is already installed. Overwrite it?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func showInstallError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Install Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func showInstallSuccess(name: String) {
        let alert = NSAlert()
        alert.messageText = "Pet Installed"
        alert.informativeText = "\(name) is ready in your nest."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
