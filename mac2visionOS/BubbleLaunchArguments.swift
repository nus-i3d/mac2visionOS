import Foundation

enum BubbleLaunchArguments {
    static let smokeHostFlag = "--bubble-smoke-host"
    static let smokeClientFlag = "--bubble-smoke-client"

    static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return BubbleProtocol.normalizedKey(arguments[index + 1])
    }
}

