import NIO
import NIOWebSocket
import NIOHTTP1
import NIOSSL
import Foundation
import NIOFoundationCompat

public final class WebSocket: @unchecked Sendable {
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }

    public var isClosed: Bool {
        !self.channel.isActive
    }
    public private(set) var closeCode: WebSocketErrorCode?

    public var onClose: EventLoopFuture<Void> {
        self.channel.closeFuture
    }

    private let channel: Channel

    private var onTextBufferCallback: (ByteBuffer) -> ()
    private var onBinaryCallback: (ByteBuffer) -> ()

    private var frameSequence: WebSocketFrameSequence?

    private var decompressor: Decompression.Decompressor?

    private var waitingForPong: Bool
    private var waitingForClose: Bool
    private var scheduledTimeoutTask: Scheduled<Void>?

    init(channel: Channel, decompression: Decompression.Configuration?) throws {
        self.channel = channel
        if let decompression = decompression {
            self.decompressor = Decompression.Decompressor()
            try self.decompressor?.initializeDecoder(encoding: decompression.algorithm)
        }
        self.onTextBufferCallback = { _ in }
        self.onBinaryCallback = { _ in }
        self.waitingForPong = false
        self.waitingForClose = false
        self.scheduledTimeoutTask = nil
    }

    /// The same as `onText`, but with raw data instead of the decoded `String`.
    public func onTextBuffer(_ callback: @escaping (ByteBuffer) -> ()) {
        self.onTextBufferCallback = callback
    }

    public func onBinary(_ callback: @escaping (ByteBuffer) -> ()) {
        self.onBinaryCallback = callback
    }

    public func send<S>(_ text: S) async throws
    where S: Collection, S.Element == Character
    {
        let promise = channel.eventLoop.makePromise(of: Void.self)
        self.send(text, promise: promise)
        try await promise.futureResult.get()
    }

    func send<S>(_ text: S, promise: EventLoopPromise<Void>? = nil)
        where S: Collection, S.Element == Character
    {
        let string = String(text)
        var buffer = channel.allocator.buffer(capacity: text.count)
        buffer.writeString(string)
        self.send(raw: buffer.readableBytesView, opcode: .text, fin: true, promise: promise)
    }

    public func send<Data>(
        raw data: Data,
        opcode: WebSocketOpcode,
        fin: Bool = true
    ) async throws where Data: DataProtocol {
        let promise = eventLoop.makePromise(of: Void.self)
        self.send(raw: data, opcode: opcode, fin: fin, promise: promise)
        try await promise.futureResult.get()
    }

    func send<Data>(
        raw data: Data,
        opcode: WebSocketOpcode,
        fin: Bool = true,
        promise: EventLoopPromise<Void>?
    ) where Data: DataProtocol {
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        let frame = WebSocketFrame(
            fin: fin,
            opcode: opcode,
            maskKey: self.makeMaskKey(),
            data: buffer
        )
        self.channel.writeAndFlush(frame, promise: promise)
    }

    public func close(code: WebSocketErrorCode = .goingAway) async throws {
        try await self.close(code: code).get()
    }

    func close(code: WebSocketErrorCode = .goingAway) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        self.close(code: code, promise: promise)
        return promise.futureResult
    }

    func close(
        code: WebSocketErrorCode = .goingAway,
        promise: EventLoopPromise<Void>?
    ) {
        guard !self.isClosed else {
            promise?.succeed(())
            return
        }
        guard !self.waitingForClose else {
            promise?.succeed(())
            return
        }
        self.waitingForClose = true
        self.closeCode = code

        let codeAsInt = UInt16(webSocketErrorCode: code)
        let codeToSend: WebSocketErrorCode
        if codeAsInt == 1005 || codeAsInt == 1006 {
            /// Code 1005 and 1006 are used to report errors to the application, but must never be sent over
            /// the wire (per https://tools.ietf.org/html/rfc6455#section-7.4)
            codeToSend = .normalClosure
        } else {
            codeToSend = code
        }

        var buffer = channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: codeToSend)

        self.send(raw: buffer.readableBytesView, opcode: .connectionClose, fin: true, promise: promise)
    }

    func makeMaskKey() -> WebSocketMaskingKey? {
        var bytes: [UInt8] = []
        for _ in 0..<4 {
            bytes.append(.random(in: .min ..< .max))
        }
        return WebSocketMaskingKey(bytes)
    }

    func handle(incoming frame: WebSocketFrame) {
        switch frame.opcode {
        case .connectionClose:
            if self.waitingForClose {
                // peer confirmed close, time to close channel
                self.channel.close(mode: .all, promise: nil)
            } else {
                // peer asking for close, confirm and close output side channel
                let promise = self.eventLoop.makePromise(of: Void.self)
                var data = frame.data
                let maskingKey = frame.maskKey
                if let maskingKey = maskingKey {
                    data.webSocketUnmask(maskingKey)
                }
                self.close(
                    code: data.readWebSocketErrorCode() ?? .unknown(1005),
                    promise: promise
                )
                promise.futureResult.whenComplete { _ in
                    self.channel.close(mode: .all, promise: nil)
                }
            }
        case .ping:
            if frame.fin {
                var frameData = frame.data
                let maskingKey = frame.maskKey
                if let maskingKey = maskingKey {
                    frameData.webSocketUnmask(maskingKey)
                }
                self.send(
                    raw: frameData.readableBytesView,
                    opcode: .pong,
                    fin: true,
                    promise: nil
                )
            } else {
                self.close(code: .protocolError, promise: nil)
            }
        case .pong:
            if frame.fin {
                var frameData = frame.data
                let maskingKey = frame.maskKey
                if let maskingKey = maskingKey {
                    frameData.webSocketUnmask(maskingKey)
                }
                self.waitingForPong = false
            } else {
                self.close(code: .protocolError, promise: nil)
            }
        case .text, .binary:
            // create a new frame sequence or use existing
            var frameSequence: WebSocketFrameSequence
            if let existing = self.frameSequence {
                frameSequence = existing
            } else {
                frameSequence = WebSocketFrameSequence(type: frame.opcode)
            }
            
            // append this frame and update the sequence
            frameSequence.append(frame)
            self.frameSequence = frameSequence
        case .continuation:
            // we must have an existing sequence
            if var frameSequence = self.frameSequence {
                // append this frame and update
                frameSequence.append(frame)
                self.frameSequence = frameSequence
            } else {
                self.close(code: .protocolError, promise: nil)
            }
        default:
            // We ignore all other frames.
            break
        }

        // if this frame was final and we have a non-nil frame sequence,
        // output it to the websocket and clear storage
        if var frameSequence = self.frameSequence, frame.fin {
            switch frameSequence.type {
            case .binary:
                if decompressor != nil {
                    do {
                        var buffer = ByteBuffer()
                        try decompressor!.decompress(part: &frameSequence.buffer, buffer: &buffer)
                        
                        self.onBinaryCallback(buffer)
                    } catch {
                        self.close(code: .protocolError, promise: nil)
                        return
                    }
                } else {
                    self.onBinaryCallback(frameSequence.buffer)
                }
            case .text:
                self.onTextBufferCallback(frameSequence.buffer)
            case .ping, .pong:
                assertionFailure("Control frames never have a frameSequence")
            default: break
            }
            self.frameSequence = nil
        }
    }

    deinit {
        self.decompressor?.deinitializeDecoder()
        assert(self.isClosed, "WebSocket was not closed before deinit.")
    }
}

private struct WebSocketFrameSequence {
    var buffer: ByteBuffer
    var type: WebSocketOpcode

    init(type: WebSocketOpcode) {
        self.buffer = ByteBufferAllocator().buffer(capacity: 0)
        self.type = type
    }

    mutating func append(_ frame: WebSocketFrame) {
        switch type {
        case .binary, .text:
            var data = frame.unmaskedData
            self.buffer.writeBuffer(&data)
        default: break
        }
    }
}
