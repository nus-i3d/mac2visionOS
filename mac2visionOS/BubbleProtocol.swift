import Foundation

enum BubbleProtocol {
    static let serviceType = "_m2vo._tcp"
    static let servicePrefix = "mac2visionOS"

    static func normalizedKey(_ key: String) -> String {
        key.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4).description
    }

    static func serviceName(for key: String) -> String {
        "\(servicePrefix)-\(normalizedKey(key))"
    }

    static func isValidKey(_ key: String) -> Bool {
        normalizedKey(key).count == 4
    }
}

enum BubbleRole: String, Codable {
    case visionHost
    case macController
}

enum BubbleAction: String, CaseIterable, Codable, Identifiable {
    case ping
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case select
    case reset

    var id: String { rawValue }

    var title: String {
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

struct BubblePeerHello: Codable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let groupKey: String
    let role: BubbleRole
}

struct BubbleCommand: Codable, Identifiable, Equatable {
    let id: UUID
    let senderID: UUID
    let groupKey: String
    let action: BubbleAction
    let sentAt: Date
}

struct BubbleAcknowledgement: Codable, Identifiable, Equatable {
    let id: UUID
    let messageID: UUID
    let accepted: Bool
    let detail: String
    let sentAt: Date
}

enum BubbleMessage: Codable, Identifiable, Equatable {
    case hello(BubblePeerHello)
    case command(BubbleCommand)
    case acknowledgement(BubbleAcknowledgement)

    var id: UUID {
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

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

