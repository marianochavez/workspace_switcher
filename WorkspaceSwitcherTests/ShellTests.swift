import XCTest
@testable import WorkspaceSwitcher

final class ShellTests: XCTestCase {

    // MARK: - Shell.run

    func testRunEchoReturnsOutput() throws {
        let output = try Shell.run("/bin/echo", args: ["hello", "world"])
        XCTAssertEqual(output, "hello world")
    }

    func testRunNonZeroExitThrows() {
        XCTAssertThrowsError(try Shell.run("/bin/sh", args: ["-c", "exit 42"])) { error in
            guard let shellErr = error as? ShellError,
                  case .nonZeroExit(let code, _) = shellErr else {
                XCTFail("Expected ShellError.nonZeroExit, got \(error)")
                return
            }
            XCTAssertEqual(code, 42)
        }
    }

    func testRunCapturesStderr() {
        XCTAssertThrowsError(try Shell.run("/bin/sh", args: ["-c", "echo errmsg >&2; exit 1"])) { error in
            guard let shellErr = error as? ShellError,
                  case .nonZeroExit(_, let msg) = shellErr else {
                XCTFail("Expected ShellError.nonZeroExit")
                return
            }
            XCTAssertTrue(msg.contains("errmsg"), "Expected stderr content, got: \(msg)")
        }
    }

    func testRunWithEnvironment() throws {
        let output = try Shell.run("/bin/sh", args: ["-c", "echo $TEST_VAR"], environment: ["TEST_VAR": "hello123"])
        XCTAssertEqual(output, "hello123")
    }

    // MARK: - Shell.runAsync

    func testRunAsyncReturnsOutput() async throws {
        let output = try await Shell.runAsync("/bin/echo", args: ["async"])
        XCTAssertEqual(output, "async")
    }

    func testRunAsyncThrowsOnFailure() async {
        do {
            _ = try await Shell.runAsync("/bin/sh", args: ["-c", "exit 1"])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is ShellError)
        }
    }

    // MARK: - CancellableProcess

    func testCancellableProcessCanBeAwaited() async throws {
        let proc = try Shell.launchCancellable("/bin/echo", args: ["test"])
        let output = try await proc.waitForExit()
        XCTAssertEqual(output, "test")
    }

    func testCancellableProcessCanBeCancelled() async throws {
        // Start a long-running process
        let proc = try Shell.launchCancellable("/bin/sleep", args: ["10"])
        XCTAssertTrue(proc.process.isRunning)

        proc.cancel()

        // Give it a moment to terminate
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(proc.process.isRunning)
    }

    func testCancellableProcessObserveStderr() async throws {
        // Use sleep to keep process alive while observer is attached
        let proc = try Shell.launchCancellable("/bin/sh", args: ["-c", "sleep 0.1; echo stderr_msg >&2"])
        let expectation = XCTestExpectation(description: "stderr received")
        var captured = ""

        proc.observeStderr { text in
            captured += text
            expectation.fulfill()
        }

        _ = try? await proc.waitForExit()
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssertTrue(captured.contains("stderr_msg"), "Expected stderr content, got: \(captured)")
    }

    func testCancellableProcessThrowsOnNonZero() async {
        do {
            let proc = try Shell.launchCancellable("/bin/sh", args: ["-c", "exit 3"])
            _ = try await proc.waitForExit()
            XCTFail("Expected error")
        } catch {
            guard let shellErr = error as? ShellError,
                  case .nonZeroExit(let code, _) = shellErr else {
                XCTFail("Expected ShellError.nonZeroExit")
                return
            }
            XCTAssertEqual(code, 3)
        }
    }
}
