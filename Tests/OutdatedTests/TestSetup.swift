import Logging

// Test-specific logging setup to suppress log output during tests
private let testSetup: Void = {
    LoggingSystem.bootstrap { _ in
        SwiftLogNoOpLogHandler()
    }
}()

// Force initialization by accessing the setup
public func initializeTestLogging() {
    _ = testSetup
}
