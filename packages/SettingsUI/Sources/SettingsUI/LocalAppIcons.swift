import AppKit

public enum LocalAppIcons {
    public static let defaultName = "Default"
    public static let names = [defaultName, "Azure", "Orange", "Legacy", "NeonBlue", "Sparkling", "Night", "Pro", "Glass", "Black"]
    private static let key = "spacegramLocalAppIcon"

    public static var selected: String {
        get {
            let value = UserDefaults.standard.string(forKey: key) ?? defaultName
            return names.contains(value) ? value : defaultName
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    public static func path(_ name: String) -> String? {
        return Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "AppIcons")?.path
    }

    public static var selectedPath: String? {
        let name = selected
        return name == defaultName ? nil : path(name)
    }

    public static func select(_ name: String) {
        selected = name
        Dock.setCustomAppIcon(path: selectedPath)
    }
}
