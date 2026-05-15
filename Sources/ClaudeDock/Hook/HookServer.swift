import Foundation
import NIO
import NIOHTTP1
import Logging

/// Actor-based local HTTP server that receives Claude Code hook events.
///
/// Lifecycle:
/// - `start()` is idempotent: calling it twice is a no-op once bound.
/// - On bind failure, `start()` shuts down the underlying `EventLoopGroup`
///   to avoid leaking threads. **A HookServer that failed to start is
///   single-shot: subsequent `start()` calls will fail because the
///   EventLoopGroup is dead.** Construct a new instance to retry.
/// - `stop()` is idempotent and a no-op when never started.
actor HookServer {
    typealias HookHandler = @Sendable (HookEvent, TerminalHint) async -> Void

    /// Reference box so the channel initializer (a Sendable closure that can't
    /// touch actor state) can pull the current LatencyTracker each time it
    /// builds a handler.
    final class LatencyBox: @unchecked Sendable {
        var tracker: LatencyTracker?
    }

    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    private(set) var port: Int = 0
    private let log = Logger(label: "claudedock.hook.server")
    private var handler: HookHandler?
    private let latencyBox = LatencyBox()

    func setHandler(_ h: @escaping HookHandler) {
        handler = h
    }

    func setLatencyTracker(_ t: LatencyTracker) {
        latencyBox.tracker = t
    }

    func start() async throws {
        guard channel == nil else { return }   // idempotent
        let box = latencyBox
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 8)
            .childChannelInitializer { [weak self] channel in
                let weakSelf = self
                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HookHTTPHandler(latencyTracker: box.tracker) { event, hint in
                        await weakSelf?.invokeHandler(event, hint)
                    })
                }
            }
        do {
            let ch = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
            channel = ch
            port = ch.localAddress?.port ?? 0
            log.info("HookServer listening on 127.0.0.1:\(port)")

            try PathProvider.ensureDirectoriesExist()

            // Write port and pid files atomically (Data.write(options: .atomic) does temp-file + rename
            // under the hood, so a wrapper script reading runtime/port can never see a torn write).
            try "\(port)".data(using: .utf8)!
                .write(to: PathProvider.runtimePortFile, options: .atomic)
            try "\(ProcessInfo.processInfo.processIdentifier)".data(using: .utf8)!
                .write(to: PathProvider.runtimePidFile, options: .atomic)
        } catch {
            // bind failed — don't leak the EventLoopGroup
            try? await group.shutdownGracefully()
            throw error
        }
    }

    func stop() async throws {
        guard channel != nil else { return }    // idempotent
        try? FileManager.default.removeItem(at: PathProvider.runtimePortFile)
        try? FileManager.default.removeItem(at: PathProvider.runtimePidFile)
        try await channel?.close()
        channel = nil
        try await group.shutdownGracefully()
    }

    private func invokeHandler(_ event: HookEvent, _ hint: TerminalHint) async {
        await handler?(event, hint)
    }
}

private final class HookHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var buffer = ByteBuffer()
    private var method: HTTPMethod = .GET
    private var uri: String = ""
    private var requestStart: Date?
    private let latencyTracker: LatencyTracker?
    private let onEvent: @Sendable (HookEvent, TerminalHint) async -> Void

    init(latencyTracker: LatencyTracker?, onEvent: @escaping @Sendable (HookEvent, TerminalHint) async -> Void) {
        self.latencyTracker = latencyTracker
        self.onEvent = onEvent
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case .head(let head):
            method = head.method
            uri = head.uri
            buffer.clear()
            requestStart = Date()
        case .body(var slice):
            buffer.writeBuffer(&slice)
        case .end:
            if method == .POST && uri.hasPrefix("/hook") {
                if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                    let data = Data(bytes)
                    if let event = try? JSONDecoder().decode(HookEvent.self, from: data) {
                        let comps = URLComponents(string: "http://127.0.0.1\(uri)")
                        let hint = TerminalHint.parse(queryItems: comps?.queryItems)
                        let cb = onEvent
                        Task { await cb(event, hint) }
                    }
                }
                if let start = requestStart {
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    latencyTracker?.record(milliseconds: ms)
                }
                respond(context: context, status: .ok)
            } else if method == .GET && uri == "/health" {
                respond(context: context, status: .ok, body: #"{"ok":true}"#)
            } else {
                respond(context: context, status: .notFound)
            }
        }
    }

    private func respond(context: ChannelHandlerContext, status: HTTPResponseStatus, body: String = "") {
        let head = HTTPResponseHead(version: .http1_1, status: status,
                                    headers: HTTPHeaders([("Content-Length", "\(body.utf8.count)")]))
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        if !body.isEmpty {
            var buf = context.channel.allocator.buffer(capacity: body.utf8.count)
            buf.writeString(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        }
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}
