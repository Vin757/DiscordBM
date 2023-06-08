import UnstableEnumMacro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class UnstableEnumMacroTests: XCTestCase {

    let macros: [String: any Macro.Type] = [
        "UnstableEnum": UnstableEnumMacro.self
    ]

    func testStringEnum() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<String>
            enum MyEnum: RawRepresentable {
                case a
                case b // bb
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a
                case b // bb
                case unknown(String)
                var rawValue: String {
                    switch self {
                    case .a:
                        return "a"
                    case .b:
                        return "bb"
                    case let .unknown(value):
                        return value
                    }
                }
                init? (rawValue: String) {
                    switch rawValue {
                    case "a":
                        self = .a
                    case "bb":
                        self = .b
                    default:
                        self = .unknown(rawValue)
                    }
                }
            }
            """,
            macros: macros
        )

        assertMacroExpansion(
            """
            @UnstableEnum<String>
            enum MyEnum: RawRepresentable {
                case a // "oo"
                case b // "bb"
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // "oo"
                case b // "bb"
                case unknown(String)
                var rawValue: String {
                    switch self {
                    case .a:
                        return "oo"
                    case .b:
                        return "bb"
                    case let .unknown(value):
                        return value
                    }
                }
                init? (rawValue: String) {
                    switch rawValue {
                    case "oo":
                        self = .a
                    case "bb":
                        self = .b
                    default:
                        self = .unknown(rawValue)
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testIntEnum() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<Int>
            enum MyEnum: RawRepresentable {
                case a // 1
                case b // 5
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // 1
                case b // 5
                case unknown(Int)
                var rawValue: Int {
                    switch self {
                    case .a:
                        return 1
                    case .b:
                        return 5
                    case let .unknown(value):
                        return value
                    }
                }
                init? (rawValue: Int) {
                    switch rawValue {
                    case 1:
                        self = .a
                    case 5:
                        self = .b
                    default:
                        self = .unknown(rawValue)
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testKeepsPublicAccessModifier() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<String>
            public enum MyEnum: RawRepresentable {
                case a
                case b // bb
            }
            """,
            expandedSource: """

            public enum MyEnum: RawRepresentable {
                case a
                case b // bb
                case unknown(String)
                public var rawValue: String {
                    switch self {
                    case .a:
                        return "a"
                    case .b:
                        return "bb"
                    case let .unknown(value):
                        return value
                    }
                }
                public init? (rawValue: String) {
                    switch rawValue {
                    case "a":
                        self = .a
                    case "bb":
                        self = .b
                    default:
                        self = .unknown(rawValue)
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testBadIntEnum() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<Int>
            enum MyEnum: RawRepresentable {
                case a // 1
                case b
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // 1
                case b
            }
            """,
            diagnostics: [.init(
                message: "allEnumCasesWithIntTypeMustHaveACommentForValue",
                line: 1,
                column: 1
            )],
            macros: macros
        )
    }

    func testProgrammerErrorWrongArgumentType() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<Int>
            enum MyEnum: RawRepresentable {
                case a // bb
                case b // 1
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // bb
                case b // 1
            }
            """,
            diagnostics: [.init(
                message: "intEnumMustOnlyHaveIntValues",
                line: 1,
                column: 1
            )],
            macros: macros
        )

        assertMacroExpansion(
            """
            @UnstableEnum<String>
            enum MyEnum: RawRepresentable {
                case a // 2
                case b // 1
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // 2
                case b // 1
            }
            """,
            diagnostics: [.init(
                message: "enumSeemsToHaveIntValuesButGenericArgumentSpecifiesString",
                line: 1,
                column: 1
            )],
            macros: macros
        )
    }

    func testValuesNotUnique() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<String>
            enum MyEnum: RawRepresentable {
                case a // 1
                case b // 1
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // 1
                case b // 1
            }
            """,
            diagnostics: [.init(
                message: "valuesMustBeUnique",
                line: 1,
                column: 1
            )],
            macros: macros
        )
    }

    func testStringValuesNoQuotation() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<String>
            enum MyEnum: RawRepresentable {
                case a // "g"
                case b // "gg"
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a // "g"
                case b // "gg"
            }
            """,
            diagnostics: [.init(
                message: "stringValuesMustNotHaveQuotation",
                line: 1,
                column: 1
            )],
            macros: macros
        )
    }

    func testNoRawValues() throws {
        assertMacroExpansion(
            """
            @UnstableEnum<String>
            enum MyEnum: RawRepresentable {
                case a = "g"
                case b = "gg"
            }
            """,
            expandedSource: """

            enum MyEnum: RawRepresentable {
                case a = "g"
                case b = "gg"
            }
            """,
            diagnostics: [.init(
                message: "rawValuesNotAcceptable",
                line: 1,
                column: 1
            )],
            macros: macros
        )
    }
}