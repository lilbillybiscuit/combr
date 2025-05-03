import XCTest
import class Foundation.Bundle

final class combrTests: XCTestCase {
    func testHelpFlag() throws {
        let binary = productsDirectory.appendingPathComponent("combr")
        
        let process = Process()
        process.executableURL = binary
        process.arguments = ["--help"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        
        XCTAssertNotNil(output)
        XCTAssertTrue(output?.contains("Usage:") ?? false)
        XCTAssertTrue(output?.contains("Options:") ?? false)
    }
    
    var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }
}