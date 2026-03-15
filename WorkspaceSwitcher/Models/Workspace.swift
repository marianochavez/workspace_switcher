import AppKit
import Foundation

struct Workspace: Identifiable, Codable {
    var id: UUID
    var name: String
    var icon: WorkspaceIcon
    var accounts: [Account]

    init(id: UUID = UUID(), name: String, icon: WorkspaceIcon = .emoji("💼"), accounts: [Account] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.accounts = accounts
    }
}

enum WorkspaceIcon: Codable, Equatable {
    case emoji(String)
    case sfSymbol(String)

    var displayString: String {
        switch self {
        case .emoji(let e): return e
        case .sfSymbol(let s): return s
        }
    }

    var nsImage: NSImage? {
        switch self {
        case .emoji(let e):
            let size = NSSize(width: 20, height: 20)
            let img = NSImage(size: size)
            img.lockFocus()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16)
            ]
            let str = e as NSString
            let strSize = str.size(withAttributes: attrs)
            let point = NSPoint(
                x: (size.width - strSize.width) / 2,
                y: (size.height - strSize.height) / 2
            )
            str.draw(at: point, withAttributes: attrs)
            img.unlockFocus()
            return img
        case .sfSymbol(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
    }
}
