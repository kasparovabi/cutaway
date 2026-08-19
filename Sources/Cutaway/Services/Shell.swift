import Foundation

enum Shell {
    static let managedBin: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cutaway/bin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let toolPath =
        "\(managedBin.path):/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin:/usr/bin:/bin"

    static func tool(_ name: String) -> URL? {
        toolPath.split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func run(_ name: String, _ arguments: [String]) async throws -> String {
        guard let executable = tool(name) else { throw ShellError.toolMissing(name) }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = toolPath
        process.environment = environment

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice

        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let text = String(data: errorData, encoding: .utf8) ?? ""
            throw ShellError.failed(name, String(text.suffix(240)))
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

enum ShellError: LocalizedError {
    case toolMissing(String)
    case failed(String, String)

    var errorDescription: String? {
        switch self {
        case .toolMissing(let name): String(localized: "\(name) not found")
        case .failed(let name, let detail): String(localized: "\(name) failed: \(detail)")
        }
    }
}
