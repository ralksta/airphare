import Foundation

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}

public enum ShellRunner {
    public static func run(
        executable: String,
        arguments: [String],
        timeoutSeconds: TimeInterval = 30
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            final class State: @unchecked Sendable {
                let lock = NSLock()
                var resumed = false
                var stdoutData = Data()
                var stderrData = Data()
            }
            let state = State()

            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                state.lock.lock()
                state.stdoutData = data
                state.lock.unlock()
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .utility).async {
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                state.lock.lock()
                state.stderrData = data
                state.lock.unlock()
                group.leave()
            }

            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                if !Task.isCancelled && process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { proc in
                timeoutTask.cancel()
                group.notify(queue: .global(qos: .utility)) {
                    state.lock.lock()
                    let shouldResume = !state.resumed
                    state.resumed = true
                    let out = String(data: state.stdoutData, encoding: .utf8) ?? ""
                    let err = String(data: state.stderrData, encoding: .utf8) ?? ""
                    state.lock.unlock()

                    if shouldResume {
                        continuation.resume(returning: CommandResult(
                            exitCode: proc.terminationStatus,
                            stdout: out,
                            stderr: err
                        ))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                state.lock.lock()
                let shouldResume = !state.resumed
                state.resumed = true
                state.lock.unlock()
                if shouldResume {
                    continuation.resume(returning: CommandResult(
                        exitCode: -1,
                        stdout: "",
                        stderr: error.localizedDescription
                    ))
                }
            }
        }
    }
}
