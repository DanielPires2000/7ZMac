import Foundation
let extensionURL = URL(fileURLWithPath: "/Applications/Safari.app/Contents/PlugIns/SafariExtension.appex")
let appURL = extensionURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
print(appURL.path)
