import Foundation

public enum BubbleLaunchArguments {
    public static let smokeHostFlag = "--bubble-smoke-host"
    public static let smokeClientFlag = "--bubble-smoke-client"
    public static let stabilityClientFlag = "--bubble-stability-client"

    public static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return BubbleProtocol.normalizedKey(arguments[index + 1])
    }
}
