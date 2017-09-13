//
//  BusyTests.swift
//
//  Copyright (c) 2015-present Nike, Inc. (https://www.nike.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import SQift
import SQLite3
import XCTest

class BusyTestCase: BaseConnectionTestCase {

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        do {
            try connection.execute("PRAGMA journal_mode = WAL")
        } catch {
            // No-op
        }
    }

    // MARK: - Tests

    func testThatConnectionCanSetTimeoutBusyHandler() {
        do {
            // Given
            try TestTables.insertDummyAgents(count: 1_000, connection: connection)

            let readConnection = try Connection(storageLocation: storageLocation, readOnly: true)

            let readExpectation = self.expectation(description: "agents should be retrieved from database")
            let checkpointExpectation = self.expectation(description: "checkpoint operation should succeed")

            var agents: [Agent]?
            var checkpointError: Error?

            // When
            let timeout: TimeInterval

            // CN (8/21/17) - I can't find a way around this issue. It seems that iOS 10 and 11 might have a
            // simulator bug or potentially a bug in SQLite where the timeout is actually in nanoseconds instead
            // of milliseconds. By bumping the value up, the tests do pass. Because of this, I'd strongly advocate
            // that people only ever use custom busy handlers that track their own timing rather than using the
            // timeout busy handler. Again, this may only be an issue in the unit tests and the simulator.
            //
            // I also tested using `PRAGMA busy_timeout = 2000` and the same behavior is observed. I can't find
            // any information about this online which is odd, but we should really avoid using this in production.
            if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
                timeout = 20_000.0
                // try connection.execute("PRAGMA busy_timeout = 2000")
            } else {
                timeout = 2.0
            }

            try connection.busyHandler(.timeout(timeout)) // throws SQLITE_BUSY error if this is disabled

            DispatchQueue.utility.async {
                do {
                    agents = try readConnection.query("SELECT * FROM agents")
                    readExpectation.fulfill()
                } catch {
                    // No-op
                }
            }

            DispatchQueue.utility.asyncAfter(seconds: 0.01) {
                do {
                    _ = try self.connection.checkpoint(mode: .truncate)
                    checkpointExpectation.fulfill()
                } catch {
                    checkpointError = error
                    checkpointExpectation.fulfill()
                }
            }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertEqual(agents?.count, 1_002)
            XCTAssertNil(checkpointError)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanSetCustomBusyHandler() {
        do {
            // Given
            try TestTables.insertDummyAgents(count: 1_000, connection: connection)

            let readConnection = try Connection(storageLocation: storageLocation, readOnly: true)

            let expectation = self.expectation(description: "agents should be retrieved from database")
            var agents: [Agent]?
            var busyInvocationCount: Int32 = 0
            var checkpointError: Error?

            // When
            try connection.busyHandler(
                .custom { attempts in
                    busyInvocationCount = attempts + 1
                    return true
                }
            )

            DispatchQueue.utility.async {
                do {
                    agents = try readConnection.query("SELECT * FROM agents")
                    expectation.fulfill()
                } catch {
                    // No-op
                }
            }

            DispatchQueue.utility.asyncAfter(seconds: 0.001) {
                do {
                    _ = try self.connection.checkpoint(mode: .truncate)
                } catch {
                    checkpointError = error
                }
            }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertEqual(agents?.count, 1_002)
            XCTAssertNil(checkpointError)
            XCTAssertGreaterThan(busyInvocationCount, 0)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanSetDefaultBehaviorBusyHandler() {
        do {
            // Given
            try TestTables.insertDummyAgents(count: 1_000, connection: connection)

            let readConnection = try Connection(storageLocation: storageLocation, readOnly: true)

            let expectation = self.expectation(description: "agents should be retrieved from database")
            var agents: [Agent]?
            var checkpointError: Error?

            // When
            try connection.busyHandler(.defaultBehavior)

            DispatchQueue.utility.async {
                do {
                    agents = try readConnection.query("SELECT * FROM agents")
                    expectation.fulfill()
                } catch {
                    // No-op
                }
            }

            DispatchQueue.utility.asyncAfter(seconds: 0.001) {
                do {
                    _ = try self.connection.checkpoint(mode: .truncate)
                } catch {
                    checkpointError = error
                }
            }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertEqual(agents?.count, 1_002)
            XCTAssertNotNil(checkpointError)

            if let error = checkpointError as? SQLiteError {
                XCTAssertEqual(error.code, SQLITE_BUSY)
                XCTAssertEqual(error.message, "database is locked")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}
