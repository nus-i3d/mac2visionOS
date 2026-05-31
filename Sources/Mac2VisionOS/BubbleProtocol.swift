import Foundation

public enum BubbleProtocol {
    public static let serviceType = "_m2vo._tcp"
    public static let servicePrefix = "mac2visionOS"

    public static func normalizedKey(_ key: String) -> String {
        String(key.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
    }

    public static func serviceName(for key: String) -> String {
        "\(servicePrefix)-\(normalizedKey(key))"
    }

    public static func isValidKey(_ key: String) -> Bool {
        normalizedKey(key).count == 4
    }
}

public enum BubbleRole: String, Codable {
    case visionHost
    case macController
}

public enum BubbleAction: String, CaseIterable, Codable, Identifiable {
    case ping
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case select
    case reset

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ping: "Ping"
        case .moveLeft: "Left"
        case .moveRight: "Right"
        case .moveUp: "Up"
        case .moveDown: "Down"
        case .select: "Select"
        case .reset: "Reset"
        }
    }
}

public struct BubblePeerHello: Codable, Identifiable, Equatable {
    public let id: UUID
    public let displayName: String
    public let groupKey: String
    public let role: BubbleRole

    public init(id: UUID, displayName: String, groupKey: String, role: BubbleRole) {
        self.id = id
        self.displayName = displayName
        self.groupKey = groupKey
        self.role = role
    }
}

public struct BubbleCommand: Codable, Identifiable, Equatable {
    public let id: UUID
    public let senderID: UUID
    public let groupKey: String
    public let action: BubbleAction
    public let sentAt: Date

    public init(id: UUID, senderID: UUID, groupKey: String, action: BubbleAction, sentAt: Date) {
        self.id = id
        self.senderID = senderID
        self.groupKey = groupKey
        self.action = action
        self.sentAt = sentAt
    }
}

public struct BubbleAcknowledgement: Codable, Identifiable, Equatable {
    public let id: UUID
    public let messageID: UUID
    public let accepted: Bool
    public let detail: String
    public let sentAt: Date

    public init(id: UUID, messageID: UUID, accepted: Bool, detail: String, sentAt: Date) {
        self.id = id
        self.messageID = messageID
        self.accepted = accepted
        self.detail = detail
        self.sentAt = sentAt
    }
}

public enum BubbleMessage: Codable, Identifiable, Equatable {
    case hello(BubblePeerHello)
    case command(BubbleCommand)
    case acknowledgement(BubbleAcknowledgement)

    public var id: UUID {
        switch self {
        case .hello(let hello): hello.id
        case .command(let command): command.id
        case .acknowledgement(let acknowledgement): acknowledgement.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case hello
        case command
        case acknowledgement
    }

    private enum MessageType: String, Codable {
        case hello
        case command
        case acknowledgement
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(MessageType.self, forKey: .type) {
        case .hello:
            self = .hello(try container.decode(BubblePeerHello.self, forKey: .hello))
        case .command:
            self = .command(try container.decode(BubbleCommand.self, forKey: .command))
        case .acknowledgement:
            self = .acknowledgement(try container.decode(BubbleAcknowledgement.self, forKey: .acknowledgement))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let hello):
            try container.encode(MessageType.hello, forKey: .type)
            try container.encode(hello, forKey: .hello)
        case .command(let command):
            try container.encode(MessageType.command, forKey: .type)
            try container.encode(command, forKey: .command)
        case .acknowledgement(let acknowledgement):
            try container.encode(MessageType.acknowledgement, forKey: .type)
            try container.encode(acknowledgement, forKey: .acknowledgement)
        }
    }
}
