// Sources/ClaudeDock/Util/Logger.swift
import Logging

enum LogBootstrap {
    static func configure() {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }
    }
}
