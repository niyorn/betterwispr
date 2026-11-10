import Foundation

public enum AppPaths {
    /// Reads the folder name from Info.plist, so a dev build runs beside the installed app without sharing its data.
    public static let support = URL.applicationSupportDirectory.appendingPathComponent(
        Bundle.main.object(forInfoDictionaryKey: "BetterWisprDataFolder") as? String ?? "BetterWispr", isDirectory: true)
}
