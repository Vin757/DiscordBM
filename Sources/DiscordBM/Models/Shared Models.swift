import Foundation

public struct ActionRow: Codable {
    
    public struct Component: Codable {
        
        public enum Kind: Int, Codable {
            case container = 1
            case button = 2
            case selectMenu = 3
            case textInput = 4
        }
        
        public struct Option: Codable {
            public var value: String
            public var label: String
            public var description: String?
            public var `default`: Bool?
            public var emoji: Gateway.PartialEmoji?
        }
        
        public let type: Kind
        public let components: [Component]?
        public var style: Int?
        public var custom_id: String?
        public var emoji: Gateway.Emoji?
        public var url: String?
        public var label: String?
        public var placeholder: String?
        public var disabled: Bool?
        public var `default`: Bool?
        public var max_values: Int?
        public var min_values: Int?
        public var options: [Option]?
        
        public init(type: Kind, components: [Component]) {
            self.type = type
            self.components = components
        }
    }
    
    public var type = 1
    public var components: [Component]
    
    public init(type: Int = 1, components: [Component]) {
        self.type = type
        self.components = components
    }
}

public enum StringIntDoubleBool: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    
    public var asString: String {
        switch self {
        case .string(let string): return string
        case .int(let int): return "\(int)"
        case .double(let double): return String(format: "%.2f", double)
        case .bool(let bool): return "\(bool)"
        }
    }
    
    public var boolValue: Bool? {
        switch self {
        case .bool(let bool): return bool
        default: return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            let double = try container.decode(Double.self)
            self = .double(double)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(string):
            try container.encode(string)
        case let .int(int):
            try container.encode(int)
        case let .double(double):
            try container.encode(double)
        case let .bool(bool):
            try container.encode(bool)
        }
    }
}

public enum StringOrInt: Codable {
    case string(String)
    case int(Int)
    
    public var stringValue: String {
        switch self {
        case .string(let string): return string
        case .int(let int): return "\(int)"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            let int = try container.decode(Int.self)
            self = .int(int)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(string):
            try container.encode(string)
        case let .int(int):
            try container.encode(int)
        }
    }
}

public struct CommandOption: Codable {
    
    public enum Kind: Int, Codable {
        case subCommand = 1
        case subCommandGroup = 2
        case string = 3
        case integer = 4
        case boolean = 5
        case user = 6
        case channel = 7
        case role = 8
        case mentionable = 9
        case number = 10
        case attachment = 11
    }
    
    public struct Choice: Codable {
        
        public var name: String
        public var name_localizations: [String: String]?
        public var value: StringIntDoubleBool
        
        public init(name: String, name_localizations: [String : String]? = nil, value: StringIntDoubleBool) {
            self.name = name
            self.name_localizations = name_localizations
            self.value = value
        }
    }
    
    public enum ChannelKind: Int, Codable {
        case guildText = 0
        case dm = 1
        case guildVoice = 2
        case groupDm = 3
        case guildCategory = 4
        case guildNews = 5
        case guildNewsThread = 10
        case guildPublicThread = 11
        case guildPrivateThread = 12
        case guildStageVoice = 13
        case guildDirectory = 14
        case guildForum = 15
    }
    
    public enum IntDouble: Codable {
        case int(Int)
        case double(Double)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let int = try? container.decode(Int.self) {
                self = .int(int)
            } else {
                let double = try container.decode(Double.self)
                self = .double(double)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .int(int):
                try container.encode(int)
            case let .double(double):
                try container.encode(double)
            }
        }
    }
    
    public var type: Kind
    public var name: String
    public var name_localizations: [String: String]?
    /// Required for command creation (i think).
    public var description: String?
    public var description_localizations: [String: String]?
    public var required: Bool?
    public var choices: [Choice]?
    public var options: [CommandOption]?
    public var channel_types: TolerantDecodeArray<ChannelKind>?
    public var min_value: IntDouble?
    public var max_value: IntDouble?
    public var autocomplete: Bool?
    /// Available when user inputs a value for the option.
    public var value: StringIntDoubleBool?
    
    public init(type: Kind, name: String, name_localizations: [String : String]? = nil, description: String? = nil, description_localizations: [String : String]? = nil, required: Bool? = nil, choices: [Choice]? = nil, options: [CommandOption]? = nil, channel_types: TolerantDecodeArray<ChannelKind>? = nil, min_value: IntDouble? = nil, max_value: IntDouble? = nil, autocomplete: Bool? = nil) {
        self.type = type
        self.name = name
        self.name_localizations = name_localizations
        self.description = description
        self.description_localizations = description_localizations
        self.required = required
        self.choices = choices
        self.options = options
        self.channel_types = channel_types
        self.min_value = min_value
        self.max_value = max_value
        self.autocomplete = autocomplete
    }
}

public struct Hashes: Codable {
    
    public struct Item: Codable {
        public var omitted: Bool?
        public var hash: String
        
        public init(omitted: Bool, hash: String) {
            self.omitted = omitted
            self.hash = hash
        }
    }
    
    public var version: Int
    public var roles: Item
    public var metadata: Item
    public var channels: Item
    
    public init(version: Int, roles: Item, metadata: Item, channels: Item) {
        self.version = version
        self.roles = roles
        self.metadata = metadata
        self.channels = channels
    }
}

public enum DiscordLocale: String, Codable {
    case danish = "da"
    case german = "de"
    case englishUK = "en-GB"
    case englishUS = "en-US"
    case spanish = "es-ES"
    case french = "fr"
    case croatian = "hr"
    case italian = "it"
    case lithuanian = "lt"
    case hungarian = "hu"
    case dutch = "nl"
    case norwegian = "no"
    case polish = "pl"
    case portuguese = "pt-BR"
    case romanian = "ro"
    case finnish = "fi"
    case swedish = "sv-SE"
    case vietnamese = "vi"
    case turkish = "tr"
    case czech = "cs"
    case greek = "el"
    case bulgarian = "bg"
    case russian = "ru"
    case ukrainian = "uk"
    case hindi = "hi"
    case thai = "th"
    case chineseChina = "zh-CN"
    case japanese = "ja"
    case chineseTaiwan = "zh-TW"
    case korean = "ko"
}

public struct DiscordTimestamp: Codable {
    
    public enum DecodingError: Error {
        case unexpectedFormat([CodingKey], String)
        case conversionFailure([CodingKey], String, DateComponents)
    }
    
    public var date: Date
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        let startIndex = string.startIndex
        func index(_ offset: Int) -> String.Index {
            string.index(startIndex, offsetBy: offset)
        }
        
        let components: DateComponents
        
        if string.count == 32 {
            guard let year = Int(string[startIndex...index(3)]),
                  let month = Int(string[index(5)...index(6)]),
                  let day = Int(string[index(8)...index(9)]),
                  let hour = Int(string[index(11)...index(12)]),
                  let minute = Int(string[index(14)...index(15)]),
                  let second = Int(string[index(17)...index(18)]),
                  let microSecond = Int(string[index(20)...index(25)])
            else {
                throw DecodingError.unexpectedFormat(container.codingPath, string)
            }
            components = DateComponents(
                calendar: Calendar.utc,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second,
                nanosecond: microSecond * 1_000
            )
        } else if string.count == 25 {
            guard let year = Int(string[startIndex...index(3)]),
                  let month = Int(string[index(5)...index(6)]),
                  let day = Int(string[index(8)...index(9)]),
                  let hour = Int(string[index(11)...index(12)]),
                  let minute = Int(string[index(14)...index(15)]),
                  let second = Int(string[index(17)...index(18)])
            else {
                throw DecodingError.unexpectedFormat(container.codingPath, string)
            }
            components = DateComponents(
                calendar: Calendar.utc,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        } else {
            throw DecodingError.unexpectedFormat(container.codingPath, string)
        }
        guard let date = Calendar.utc.date(from: components) else {
            throw DecodingError.conversionFailure(container.codingPath, string, components)
        }
        self.date = date
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let componentSet: Set<Calendar.Component> = [
            .year, .month, .day, .hour, .minute, .second, .nanosecond
        ]
        let components = Calendar.utc.dateComponents(componentSet, from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute,
              let second = components.second,
              let nanoSecond = components.nanosecond
        else {
            throw EncodingError.invalidValue(date, .init(
                codingPath: container.codingPath,
                debugDescription: "Programming Error. Could not encode Date to Discord Timestamp."
            ))
        }
        let miliSecond = nanoSecond / 1_000
        
        func fixedDigit(_ int: Int, _ length: Int) -> String {
            let description = "\(int)"
            let zeroCount = length - description.count
            if zeroCount > 0 {
                return Array(repeating: "0", count: zeroCount) + description
            } else {
                return description
            }
        }
        
        let f = (
            year: fixedDigit(year, 4),
            month: fixedDigit(month, 2),
            day: fixedDigit(day, 2),
            hour: fixedDigit(hour, 2),
            minute: fixedDigit(minute, 2),
            second: fixedDigit(second, 2),
            mili: fixedDigit(miliSecond, 6)
        )
        
        let str = "\(f.year)-\(f.month)-\(f.day)T\(f.hour):\(f.minute):\(f.second).\(f.mili)+00:00"
        
        try container.encode(str)
    }
}

private enum BitFieldError: Error {
    case notRepresentingInt
}

public protocol BitField: ExpressibleByArrayLiteral {
    associatedtype R: RawRepresentable where R.RawValue == Int
    var values: [R] { get set }
    var unknownValues: [Int] { get set }
    init(values: [R], unknownValues: [Int])
}

public extension BitField {
    
    init(arrayLiteral elements: R...) {
        self.init(values: elements, unknownValues: [])
    }
    
    init(bitValue: Int) {
        var bitValue = bitValue
        var values: ContiguousArray<R> = []
        var unknownValues: [Int] = []
        while bitValue != 0 {
            let halfUp = (bitValue / 2) + 1
            let log = log2(Double(halfUp))
            let intValue = Int(log.rounded(.up))
            
            if let newValue = R(rawValue: intValue) {
                values.append(newValue)
            } else {
                unknownValues.append(intValue)
            }
            bitValue -= 1 << intValue
        }
        
        if !unknownValues.isEmpty {
            bitFieldLogger.warning("Non empty unknown values", metadata: [
                "unknownValues": "\(unknownValues)",
                "values": "\(values.map(\.rawValue))",
                "type": "\(Swift._typeName(R.self))"
            ])
        }
        
        self.init(
            values: Array(values),
            unknownValues: unknownValues
        )
    }
}

private let bitFieldLogger = DiscordGlobalConfiguration.makeLogger("BitField")

public struct IntBitField<R>: BitField, Codable
where R: RawRepresentable, R.RawValue == Int {
    
    public var values: [R]
    public var unknownValues: [Int]
    
    public init(values: [R], unknownValues: [Int] = []) {
        self.values = values
        self.unknownValues = unknownValues
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let int = try container.decode(Int.self)
        self.init(bitValue: int)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let value = (values.map(\.rawValue) + unknownValues).map({ 1 << $0 }).reduce(into: 0, +=)
        try container.encode(value)
    }
}

public struct StringBitField<R>: BitField, Codable
where R: RawRepresentable, R.RawValue == Int {
    
    public var values: [R]
    public var unknownValues: [Int]
    
    public init(values: [R], unknownValues: [Int] = []) {
        self.values = values
        self.unknownValues = unknownValues
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let int = Int(string) else {
            throw BitFieldError.notRepresentingInt
        }
        self.init(bitValue: int)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let value = (values.map(\.rawValue) + unknownValues).map({ 1 << $0 }).reduce(into: 0, +=)
        try container.encode("\(value)")
    }
}

public struct IntPair: Codable {
    public var first: Int
    public var second: Int
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let array = try container.decode([Int].self)
        guard array.count == 2 else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "Expected 2 integers in the array, found \(array.count)."
            ))
        }
        self.first = array[0]
        self.second = array[1]
    }
    
    public func encode(to encoder: Encoder) throws {
        try [first, second].encode(to: encoder)
    }
}

//MARK: - DecodeTolerable

private let decodeTolerableLogger = DiscordGlobalConfiguration.makeLogger("DecodeTolerable")

public struct TolerantDecodeArray<Element>: Codable, ExpressibleByArrayLiteral
where Element: RawRepresentable, Element.RawValue: Codable
{
    
    public var values: [Element]
    
    public init<S>(_ values: S) where S: Sequence, S.Element == Element {
        self.values = .init(values)
    }
    
    public init(arrayLiteral elements: Element...) {
        self.values = elements
    }
    
    public init() {
        self.values = []
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        var values: ContiguousArray<Element> = []
        var badValues: [Element.RawValue] = []
        while !container.isAtEnd {
            let rawValue = try container.decode(Element.RawValue.self)
            if let value = Element.init(rawValue: rawValue) {
                values.append(value)
            } else {
                badValues.append(rawValue)
            }
        }
        if !badValues.isEmpty {
            decodeTolerableLogger.warning("DecodeTolerable found unconsidered values.", metadata: [
                "values": "\(values)",
                "badValues": "\(badValues)",
                "codingPath": "\(container.codingPath.map(\.debugDescription))",
                "type": "\(Swift._typeName(Self.self))"
            ])
        }
        self.init(values)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.values.map(\.rawValue).encode(to: encoder)
    }
}

public struct Embed: Codable {
    
    public enum Kind: String, Codable {
        case rich = "rich"
        case image = "image"
        case video = "video"
        case gifv = "gifv"
        case article = "article"
        case link = "link"
        case autoModerationMessage = "auto_moderation_message"
    }
    
    public struct Footer: Codable {
        public var text: String
        public var icon_url: String?
        public var proxy_icon_url: String?
        
        public init(text: String, icon_url: String? = nil, proxy_icon_url: String? = nil) {
            self.text = text
            self.icon_url = icon_url
            self.proxy_icon_url = proxy_icon_url
        }
    }
    
    public struct Media: Codable {
        public var url: String
        public var proxy_url: String?
        public var height: Int?
        public var width: Int?
        
        public init(url: String, proxy_url: String? = nil, height: Int? = nil, width: Int? = nil) {
            self.url = url
            self.proxy_url = proxy_url
            self.height = height
            self.width = width
        }
    }
    
    public struct Provider: Codable {
        public var name: String?
        public var url: String?
        
        public init(name: String? = nil, url: String? = nil) {
            self.name = name
            self.url = url
        }
    }
    
    public struct Author: Codable {
        public var name: String
        public var url: String?
        public var icon_url: String?
        public var proxy_icon_url: String?
        
        public init(name: String, url: String? = nil, icon_url: String? = nil, proxy_icon_url: String? = nil) {
            self.name = name
            self.url = url
            self.icon_url = icon_url
            self.proxy_icon_url = proxy_icon_url
        }
    }
    
    public struct Field: Codable {
        public var name: String
        public var value: String
        public var inline: Bool?
        
        public init(name: String, value: String, inline: Bool? = nil) {
            self.name = name
            self.value = value
            self.inline = inline
        }
    }
    
    public var title: String?
    public var type: Kind?
    public var description: String?
    public var url: String?
    public var timestamp: TolerantDecodeDate? = nil
    public var color: DiscordColor?
    public var footer: Footer?
    public var image: Media?
    public var thumbnail: Media?
    public var video: Media?
    public var provider: Provider?
    public var author: Author?
    public var fields: [Field]?
    public var reference_id: String?
    
    public init(title: String? = nil, type: Embed.Kind? = nil, description: String? = nil, url: String? = nil, timestamp: Date? = nil, color: DiscordColor? = nil, footer: Embed.Footer? = nil, image: Embed.Media? = nil, thumbnail: Embed.Media? = nil, video: Embed.Media? = nil, provider: Embed.Provider? = nil, author: Embed.Author? = nil, fields: [Embed.Field]? = nil, reference_id: String? = nil) {
        self.title = title
        self.type = type
        self.description = description
        self.url = url
        self.timestamp = timestamp == nil ? nil : .init(date: timestamp!)
        self.color = color
        self.footer = footer
        self.image = image
        self.thumbnail = thumbnail
        self.video = video
        self.provider = provider
        self.author = author
        self.fields = fields
        self.reference_id = reference_id
    }
    
    private var fieldsLength: Int {
        fields?.reduce(into: 0, { $0 = $1.name.count + $1.value.count }) ?? 0
    }
    
    /// The length that matters towards the Discord limit (currently 6000 across all embeds).
    public var contentLength: Int {
        (title?.count ?? 0) +
        (description?.count ?? 0) +
        fieldsLength +
        (footer?.text.count ?? 0) +
        (author?.name.count ?? 0)
    }
}


public struct TolerantDecodeDate: Codable {
    
    public var date: Date
    
    public init(date: Date) {
        self.date = date
    }
    
    public init(from decoder: Decoder) throws {
        if let date = try? decoder.singleValueContainer().decode(Date.self) {
            self.date = date
        } else {
            self.date = try DiscordTimestamp(from: decoder).date
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.date)
    }
}

public struct DiscordColor: Codable, ExpressibleByIntegerLiteral {
    
    public let value: Int
    
    public var asRGB: (red: Int, green: Int, blue: Int) {
        let red = value >> 16
        let green = (value - (red << 16)) >> 8
        let blue = value - (red << 16) - (green << 8)
        return (red, green, blue)
    }
    
    public var asHex: String {
        "#" + String(self.value, radix: 16, uppercase: true)
    }
    
    public init(integerLiteral value: Int) {
        self.init(value: value)
    }
    
    public init(value: Int) {
        precondition(value >= 0, "Color cannot be negative.")
        precondition(value < (1 << 24), "Value \(value) exceeds max RGB.")
        self.value = value
    }
    
    public init(red: Int, green: Int, blue: Int) {
        precondition((0..<256).contains(red), "Red value \(red) is not in RGB component range.")
        precondition((0..<256).contains(green), "Green value \(green) is not in RGB component range.")
        precondition((0..<256).contains(blue), "Blue value \(blue) is not in RGB component range.")
        self.value = (red << 16) + (green << 8) + blue
    }
    
    public init(hex: String) {
        var hex = hex
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        precondition(hex.count == 6, "Hex color must be 6 letters long.")
        self.value = Int(hex, radix: 16)!
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.value.encode(to: encoder)
    }
}