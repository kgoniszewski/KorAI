import Foundation
import SwiftData

extension SchemaV1 {
    /// Rozmowa z korepetytorem w kontekście materiału lub sprawdzianu.
    @Model
    public final class ChatThread {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var title: String = ""

        public var material: StudyMaterial?
        public var assessment: Assessment?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
        public var messages: [ChatMessage]? = []

        public init(title: String = "") {
            self.title = title
        }
    }

    /// Pojedyncza wiadomość w rozmowie.
    @Model
    public final class ChatMessage {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var roleRaw: String = ChatRole.user.rawValue
        public var content: String = ""
        public var date: Date = Date.now

        public var thread: ChatThread?

        public var role: ChatRole {
            get { ChatRole(rawValue: roleRaw) ?? .user }
            set { roleRaw = newValue.rawValue }
        }

        public init(role: ChatRole = .user, content: String = "", date: Date = .now) {
            self.roleRaw = role.rawValue
            self.content = content
            self.date = date
        }
    }
}
