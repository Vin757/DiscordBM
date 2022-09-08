import Foundation

public struct ChannelCreateMessage: Codable {
    
    public struct AllowedMentions: Codable {
        
        public enum Kind: String, Codable {
            case roles
            case users
            case everyone
        }
        
        public var parse: TolerantDecodeArray<Kind>
        public var roles: [String]
        public var users: [String]
        public var replied_user: Bool
        
        public init(parse: TolerantDecodeArray<AllowedMentions.Kind>, roles: [String], users: [String], replied_user: Bool) {
            self.parse = parse
            self.roles = roles
            self.users = users
            self.replied_user = replied_user
        }
    }
    
    public struct Reference: Codable {
        public var message_id: String?
        public var channel_id: String?
        public var guild_id: String?
        public var fail_if_not_exists: Bool?
        
        public init(message_id: String? = nil, channel_id: String? = nil, guild_id: String? = nil, fail_if_not_exists: Bool? = nil) {
            self.message_id = message_id
            self.channel_id = channel_id
            self.guild_id = guild_id
            self.fail_if_not_exists = fail_if_not_exists
        }
    }
    
    public struct Attachment: Codable {
        public var id: String
        public var filename: String?
        public var description: String?
        public var content_type: String?
        public var size: Int?
        public var url: String?
        public var proxy_url: String?
        public var height: Int?
        public var width: Int?
        public var ephemeral: Bool?
        
        public init(id: String, filename: String? = nil, description: String? = nil, content_type: String? = nil, size: Int? = nil, url: String? = nil, proxy_url: String? = nil, height: Int? = nil, width: Int? = nil, ephemeral: Bool? = nil) {
            self.id = id
            self.filename = filename
            self.description = description
            self.content_type = content_type
            self.size = size
            self.url = url
            self.proxy_url = proxy_url
            self.height = height
            self.width = width
            self.ephemeral = ephemeral
        }
    }
    
    public var content: String?
    public var tts: Bool?
    public var embeds: [Embed]?
    public var allowed_mentions: AllowedMentions?
    public var message_reference: Reference?
    public var components: [ActionRow]?
    public var sticker_ids: [String]?
    public var files: [String]?
    public var payload_json: String?
    public var attachments: [Attachment]?
    public var flags: Int?
    
    public init(content: String? = nil, tts: Bool? = nil, embeds: [Embed]? = nil, allowed_mentions: AllowedMentions? = nil, message_reference: Reference? = nil, components: [ActionRow]? = nil, sticker_ids: [String]? = nil, files: [String]? = nil, payload_json: String? = nil, attachments: [Attachment]? = nil, flags: Int? = nil) {
        self.content = content
        self.tts = tts
        self.embeds = embeds
        self.allowed_mentions = allowed_mentions
        self.message_reference = message_reference
        self.components = components
        self.sticker_ids = sticker_ids
        self.files = files
        self.payload_json = payload_json
        self.attachments = attachments
        self.flags = flags
    }
}

public struct ChannelEditMessage: Codable {
    
    public typealias AllowedMentions = ChannelCreateMessage.AllowedMentions
    public typealias Attachment = ChannelCreateMessage.Attachment
    
    public var content: String?
    public var embeds: [Embed]?
    public var flags: Int?
    public var allowed_mentions: AllowedMentions?
    public var components: [ActionRow]?
    public var files: [String]?
    public var payload_json: String?
    public var attachments: [ChannelCreateMessage.Attachment]?
    
    public init(content: String? = nil, embeds: [Embed]? = nil, flags: Int? = nil, allowed_mentions: AllowedMentions? = nil, components: [ActionRow]? = nil, files: [String]? = nil, payload_json: String? = nil, attachments: [Attachment]? = nil) {
        self.content = content
        self.embeds = embeds
        self.flags = flags
        self.allowed_mentions = allowed_mentions
        self.components = components
        self.files = files
        self.payload_json = payload_json
        self.attachments = attachments
    }
}