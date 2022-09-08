import WebSocketKit
import Logging
import struct NIOCore.TimeAmount
import struct Foundation.Data
import struct Foundation.Date
import class NIO.RepeatedTask
import Atomics
import AsyncHTTPClient
import struct Foundation.UUID

public actor DiscordManager {
    
    public enum State: Int, AtomicValue {
        case noConnection
        case connecting
        case configured
        case connected
    }
    
    private var ws: WebSocket? {
        didSet {
            self.closeWebsocket(ws: oldValue)
        }
    }
    private nonisolated let eventLoopGroup: EventLoopGroup
    public nonisolated let client: DiscordClient
    
    private var onEvents: [(Gateway.Event) -> ()] = []
    private var onEventParseFilures: [(Error, String) -> ()] = []
    
    private let token: String
    public nonisolated let identifyPayload: Gateway.Identify
    
    public nonisolated let id = UUID()
    private let logger = DiscordGlobalConfiguration.makeLogger("DiscordManager")
    
    private var sequenceNumber: Int? = nil
    private var sessionId: String? = nil
    private var resumeGatewayUrl: String? = nil
    private nonisolated let pingTaskInterval = ManagedAtomic(0)
    private var lastEventDate = Date()
    
    private nonisolated let _state = ManagedAtomic(State.noConnection)
    public nonisolated var state: State {
        self._state.load(ordering: .relaxed)
    }
    
    /// Counter to keep track of how many times in a sequence, a zombied connection was detected.
    private nonisolated let zombiedConnectionCounter = ManagedAtomic(0)
    /// An ID to keep track of connection changes.
    private nonisolated let connectionId = ManagedAtomic(Int.random(in: 10_000..<100_000))
    
    public init(
        eventLoopGroup: EventLoopGroup,
        httpClient: HTTPClient,
        token: String,
        appId: String,
        identifyPayload: Gateway.Identify
    ) {
        self.eventLoopGroup = eventLoopGroup
        self.client = DiscordClient(
            httpClient: httpClient,
            token: token,
            appId: appId
        )
        self.token = token
        self.identifyPayload = identifyPayload
    }
    
    public init(
        eventLoopGroup: EventLoopGroup,
        httpClient: HTTPClient,
        token: String,
        appId: String,
        presence: Gateway.Identify.PresenceUpdate? = nil,
        intents: [Gateway.Identify.Intent] = []
    ) {
        self.init(
            eventLoopGroup: eventLoopGroup,
            httpClient: httpClient,
            token: token,
            appId: appId,
            identifyPayload: .init(
                token: token,
                presence: presence,
                intents: .init(values: intents)
            )
        )
    }
    
    public nonisolated func connect() {
        Task {
            await connectAsync()
        }
    }
    
    public func requestGuildMembersChunk(payload: Gateway.RequestGuildMembers) {
        self.send(payload: .init(
            opcode: .requestGuildMembers,
            data: .requestGuildMembers(payload)
        ), opcode: 0x1)
    }
    
    public func addEventHandler(_ handler: @escaping (Gateway.Event) -> Void) {
        self.onEvents.append(handler)
    }
    
    public func addEventParseFailureHandler(_ handler: @escaping (Error, String) -> Void) {
        self.onEventParseFilures.append(handler)
    }
}

extension DiscordManager {
    private func connectAsync() async {
        let state = self._state.load(ordering: .relaxed)
        guard state == .noConnection || state == .configured else {
            return
        }
        self._state.store(.connecting, ordering: .relaxed)
        self.connectionId.store(.random(in: 10_000..<100_000), ordering: .relaxed)
        self.lastEventDate = Date()
        let gatewayUrl = await getGatewayUrl()
        var configuration = WebSocketClient.Configuration()
        configuration.maxFrameSize = 1 << 31
        WebSocket.connect(
            to: gatewayUrl + "?v=\(DiscordGlobalConfiguration.apiVersion)&encoding=json",
            configuration: configuration,
            on: eventLoopGroup
        ) { ws in
            self.ws = ws
            self.configureWebsocket()
        }.whenFailure { [self] error in
            logger.error("Error while connecting to Discord through websocket.", metadata: [
                "DiscordManagerID": .stringConvertible(id),
                "error": "\(error)"
            ])
            self._state.store(.noConnection, ordering: .relaxed)
            Task {
                await eventLoopGroup.any().wait(.seconds(5))
                await connectAsync()
            }
        }
    }
    
    private func configureWebsocket() {
        let connId = self.connectionId.load(ordering: .relaxed)
        self.setupOnText()
        self.setupOnClose(forConnectionWithId: connId)
        self.setupZombiedConnectionCheckerTask(forConnectionWithId: connId)
        self._state.store(.configured, ordering: .relaxed)
    }
    
    private func proccessEvent(_ event: Gateway.Event) {
        self.lastEventDate = Date()
        self.zombiedConnectionCounter.store(0, ordering: .relaxed)
        if let sequenceNumber = event.sequenceNumber {
            self.sequenceNumber = sequenceNumber
        }
        
        switch event.opcode {
        case .reconnect:
            break // will reconnect when we get the close notification
        case .heartbeat:
            self.sendPing()
        case .heartbeatAccepted:
            break // nothing to do
        case .invalidSession:
            logger.warning("Got invalid session. Will try to reconnect.", metadata: [
                "DiscordManagerID": .stringConvertible(id)
            ])
            self.sequenceNumber = nil
            self.resumeGatewayUrl = nil
            self.sessionId = nil
            self.connect()
        default:
            break
        }
        
        switch event.data {
        case let .hello(hello):
            let interval: TimeAmount = .milliseconds(Int64(hello.heartbeat_interval))
            /// Disable websocket-kit automatic pings
            self.ws?.pingInterval = nil
            self.setupPingTask(
                forConnectionWithId: self.connectionId.load(ordering: .relaxed),
                every: interval
            )
            self.pingTaskInterval.store(hello.heartbeat_interval, ordering: .relaxed)
            self.sendResumeOrIdentify()
        case let .ready(payload):
            logger.notice("Received ready notice.", metadata: [
                "DiscordManagerID": .stringConvertible(id)
            ])
            self._state.store(.connected, ordering: .relaxed)
            self.sessionId = payload.session_id
            self.resumeGatewayUrl = payload.resume_gateway_url
        case .resumed:
            logger.notice("Received successful resume notice.", metadata: [
                "DiscordManagerID": .stringConvertible(id)
            ])
            self._state.store(.connected, ordering: .relaxed)
        default:
            break
        }
    }
    
    private func getGatewayUrl() async -> String {
        if let gatewayUrl = self.resumeGatewayUrl {
            return gatewayUrl
        } else if let gatewayUrl = try? await client.getGateway().decode().url {
            return gatewayUrl
        } else {
            logger.error("Cannot get gateway url to connect to. Will retry in 5 seconds.", metadata: [
                "DiscordManagerID": .stringConvertible(id)
            ])
            await self.eventLoopGroup.any().wait(.seconds(5))
            return await self.getGatewayUrl()
        }
    }
    
    private func sendResumeOrIdentify() {
        if !self.sendResumeAndReport() {
            self.sendIdentify()
        }
    }
    
    /// Returns whether or not it could send the `resume`.
    private func sendResumeAndReport() -> Bool {
        if let sessionId = self.sessionId,
           let lastSequenceNumber = self.sequenceNumber {
            
            let resume = Gateway.Event(
                opcode: .resume,
                data: .resume(.init(
                    token: self.token,
                    session_id: sessionId,
                    seq: lastSequenceNumber
                ))
            )
            self.send(
                payload: resume,
                opcode: UInt8(Gateway.Opcode.identify.rawValue)
            )
            
            /// Invalidate these temporary info before for the next connection trial.
            self.sequenceNumber = nil
            self.resumeGatewayUrl = nil
            self.sessionId = nil
            
            logger.notice("Sent resume request to Discord.", metadata: [
                "DiscordManagerID": .stringConvertible(id)
            ])
            
            return true
        }
        logger.notice("Can't resume last Discord connection.", metadata: [
            "sessionId_length": .stringConvertible(self.sessionId?.count ?? -1),
            "lastSequenceNumber": .stringConvertible(self.sequenceNumber ?? -1),
            "DiscordManagerID": .stringConvertible(id)
        ])
        return false
    }
    
    private func sendIdentify() {
        let identify = Gateway.Event(
            opcode: .identify,
            data: .identify(identifyPayload)
        )
        self.send(payload: identify)
    }
    
    private func setupOnText() {
        self.ws?.onText { _, text in
            let data = Data(text.utf8)
            do {
                let event = try DiscordGlobalConfiguration.decoder.decode(
                    Gateway.Event.self,
                    from: data
                )
                self.proccessEvent(event)
                for onEvent in self.onEvents {
                    onEvent(event)
                }
            } catch {
                for onEventParseFilure in self.onEventParseFilures {
                    onEventParseFilure(error, text)
                }
            }
        }
    }
    
    private func setupOnClose(forConnectionWithId connectionId: Int) {
        self.ws?.onClose.whenComplete { [weak self] _ in
            guard let `self` = self,
                  self.connectionId.load(ordering: .relaxed) == connectionId
            else { return }
            Task {
                let code = await self.ws?.closeCode
                self.logger.log(
                    /// If its `nil` or `.goingAway`, then it's likely just a resume notice.
                    /// Otherwise it might be an error.
                    level: (code == nil || code == .goingAway) ? .warning : .error,
                    "Received connection close notification.",
                    metadata: [
                        "DiscordManagerID": .stringConvertible(self.id),
                        "code": "\(String(describing: code))"
                    ]
                )
                self._state.store(.noConnection, ordering: .relaxed)
                self.connect()
            }
        }
    }
    
    private nonisolated func setupZombiedConnectionCheckerTask(
        forConnectionWithId connectionId: Int,
        on el: EventLoop? = nil
    ) {
        guard let tolerance = DiscordGlobalConfiguration.zombiedConnectionCheckerTolerance
        else { return }
        let el = el ?? self.eventLoopGroup.any()
        el.scheduleTask(in: .seconds(10)) { [weak self] in
            guard let `self` = self else { return }
            /// If connection has changed then end this instance.
            guard self.connectionId.load(ordering: .relaxed) == connectionId else { return }
            @Sendable func reschedule(in time: TimeAmount) {
                el.scheduleTask(in: time) {
                    self.setupZombiedConnectionCheckerTask(forConnectionWithId: connectionId, on: el)
                }
            }
            Task {
                let now = Date().timeIntervalSince1970
                let lastEventInterval = await self.lastEventDate.timeIntervalSince1970
                let past = now - lastEventInterval
                let diff = tolerance - past
                if diff > 0 {
                    reschedule(in: .seconds(Int64(diff) + 1))
                } else {
                    let tryToPingBeforeForceReconnect: Bool = await {
                        if self.zombiedConnectionCounter.load(ordering: .relaxed) != 0 {
                            return false
                        } else if await self.ws == nil {
                            return false
                        } else if await self.ws!.isClosed {
                            return false
                        } else if self.pingTaskInterval.load(ordering: .relaxed) < Int(tolerance) {
                            return false
                        } else {
                            return true
                        }
                    }()
                    
                    if tryToPingBeforeForceReconnect {
                        /// Try to see if discord responds to a ping before trying to reconnect.
                        await self.sendPing()
                        self.zombiedConnectionCounter.wrappingIncrement(ordering: .relaxed)
                        reschedule(in: .seconds(5))
                    } else {
                        self.logger.error("Detected zombied connection. Will try to reconnect.", metadata: [
                            "DiscordManagerID": .stringConvertible(self.id),
                        ])
                        self._state.store(.noConnection, ordering: .relaxed)
                        self.connect()
                        reschedule(in: .seconds(30))
                    }
                }
            }
        }
    }
    
    private func setupPingTask(
        forConnectionWithId connectionId: Int,
        every interval: TimeAmount
    ) {
        self.eventLoopGroup.any().scheduleRepeatedTask(
            initialDelay: interval,
            delay: interval
        ) { [weak self] _ in
            guard let `self` = self,
                  self.connectionId.load(ordering: .relaxed) == connectionId
            else { return }
            Task {
                await self.sendPing()
            }
        }
    }
    
    private func sendPing() {
        self.send(payload: .init(opcode: .heartbeat))
    }
        
    private func send(payload: Gateway.Event, opcode: UInt8? = nil) {
        do {
            let data = try DiscordGlobalConfiguration.encoder.encode(payload)
            let opcode = opcode ?? UInt8(payload.opcode.rawValue)
            if let ws = self.ws {
                ws.send(raw: data, opcode: .init(encodedWebSocketOpcode: opcode)!)
            } else {
                logger.warning("Trying to send through ws when a connection is not established.", metadata: [
                    "DiscordManagerID": .stringConvertible(id),
                    "payload": "\(payload)",
                    "state": "\(self._state.load(ordering: .relaxed))"
                ])
            }
        } catch {
            logger.warning("Could not encode payload. This is a library issue, please report.", metadata: [
                "DiscordManagerID": .stringConvertible(id),
                "payload": "\(payload)",
                "opcode": "\(opcode ?? 255)"
            ])
        }
    }
    
    private nonisolated func closeWebsocket(ws: WebSocket?) {
        ws?.close().whenFailure { [weak self] in
            guard let `self` = self else { return }
            self.logger.warning("Connection close error.", metadata: [
                "DiscordManagerID": .stringConvertible(self.id),
                "error": "\($0)"
            ])
        }
    }
}


//MARK: - +EventLoop
private extension EventLoop {
    func wait(_ time: TimeAmount) async {
        try? await self.scheduleTask(in: time, { }).futureResult.get()
    }
}