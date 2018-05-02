//
//  TableLockPolicyTests.swift
//
//  Copyright 2015-present, Nike, Inc.
//  All rights reserved.
//
//  This source code is licensed under the BSD-stylelicense found in the LICENSE
//  file in the root directory of this source tree.
//

import Foundation
import SQift
import SQLite3
import XCTest

class TableLockPolicyTestCase: BaseConnectionTestCase {

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        do {
            try connection.execute("PRAGMA journal_mode = WAL")
        } catch {
            // No-op
        }
    }

    // MARK: - Tests - Disabled Policy

    func testThatConnectionThrowsTableLockErrorWhenWriteLockBlocksReadLock() throws {
        // Given
        let writeConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .fastFail,
            sharedCache: true
        )

        let readConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .fastFail,
            readOnly: true,
            sharedCache: true
        )

        let writeExpectation = self.expectation(description: "Write should succeed")
        let readExpectation = self.expectation(description: "Read should fail")

        var readCount: Int?
        var writeError: Error?
        var readError: Error?

        // When
        DispatchQueue.userInitiated.async {
            do {
                try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)
            } catch {
                writeError = error
            }

            writeExpectation.fulfill()
        }

        DispatchQueue.userInitiated.asyncAfter(seconds: 0.01) {
            do {
                readCount = try readConnection.query("SELECT count(*) FROM agents")
            } catch {
                readError = error
            }

            readExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(writeError)
        XCTAssertNil(readCount)
        XCTAssertNotNil(readError)

        if let readError = readError as? SQLiteError {
            XCTAssertEqual(readError.code, SQLITE_LOCKED)
        }
    }

    func testThatConnectionThrowsTableLockErrorWhenReadLockBlocksWriteLock() throws {
        // Given
        let writeConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .fastFail,
            sharedCache: true
        )

        let readConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .fastFail,
            readOnly: true,
            sharedCache: true
        )

        try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)

        let writeExpectation = self.expectation(description: "Write should fail")
        let readExpectation = self.expectation(description: "Read should succeed")

        var agents: [Agent] = []
        var writeError: Error?
        var readError: Error?

        // When
        DispatchQueue.userInitiated.async {
            do {
                agents = try readConnection.query("SELECT * FROM agents")
            } catch {
                readError = error
            }

            readExpectation.fulfill()
        }

        DispatchQueue.userInitiated.asyncAfter(seconds: 0.01) {
            do {
                try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)
            } catch {
                writeError = error
            }

            writeExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(agents.count, 1_002)
        XCTAssertNil(readError)
        XCTAssertNotNil(writeError)

        if let writeError = writeError as? SQLiteError {
            XCTAssertEqual(writeError.code, SQLITE_LOCKED)
        }
    }

    func testThatConnectionThrowsTableLockErrorWhenReadLockBlocksWriteLockThroughExecute() throws {
        // Given
        let writeConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .fastFail,
            sharedCache: true
        )

        let readConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .fastFail,
            readOnly: true,
            sharedCache: true
        )

        try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)

        let writeExpectation = self.expectation(description: "Write should fail")
        let readExpectation = self.expectation(description: "Read should succeed")

        var agents: [Agent] = []
        var writeError: Error?
        var readError: Error?

        // When
        DispatchQueue.userInitiated.async {
            do {
                agents = try readConnection.query("SELECT * FROM agents")
            } catch {
                readError = error
            }

            readExpectation.fulfill()
        }

        DispatchQueue.userInitiated.asyncAfter(seconds: 0.01) {
            do {
                let dateString = bindingDateFormatter.string(from: Date())

                let sql = """
                    INSERT INTO agents(name, date, missions, salary, job_title, car)
                    VALUES('name', '\(dateString)', 13.123, 20, '\("job".data(using: .utf8)!)', NULL)
                    """

                try writeConnection.execute(sql)
            } catch {
                writeError = error
            }

            writeExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(agents.count, 1_002)
        XCTAssertNil(readError)
        XCTAssertNotNil(writeError)

        if let writeError = writeError as? SQLiteError {
            XCTAssertEqual(writeError.code, SQLITE_LOCKED)
        }
    }

    // MARK: - Tests - Enabled Policy

    func testThatConnectionDoesNotThrowErrorWhenWriteLockBlocksReadLockWithTableLockPolicyEnabled() throws {
        // Given
        let writeConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .poll(0.01),
            sharedCache: true
        )

        let readConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .poll(0.01),
            readOnly: true,
            sharedCache: true
        )

        let writeExpectation = self.expectation(description: "Write should succeed")
        let readExpectation = self.expectation(description: "Read should succeed")

        var readCount: Int?
        var writeError: Error?
        var readError: Error?

        // When
        DispatchQueue.userInitiated.async {
            do {
                try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)
            } catch {
                writeError = error
            }

            writeExpectation.fulfill()
        }

        DispatchQueue.userInitiated.asyncAfter(seconds: 0.01) {
            do {
                readCount = try readConnection.query("SELECT count(*) FROM agents")
            } catch {
                readError = error
            }

            readExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(writeError)
        XCTAssertNil(readError)
        XCTAssertEqual(readCount, 1_002)
    }

    func testThatConnectionDoesNotThrowErrorWhenReadLockBlocksWriteLockWithTableLockPolicyEnabled() throws {
        // Given
        let writeConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .poll(0.01),
            sharedCache: true
        )

        let readConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .poll(0.01),
            readOnly: true,
            sharedCache: true
        )

        try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)

        let writeExpectation = self.expectation(description: "Write should succeed")
        let readExpectation = self.expectation(description: "Read should succeed")

        var agents: [Agent] = []
        var writeError: Error?
        var readError: Error?

        // When
        DispatchQueue.userInitiated.async {
            do {
                agents = try readConnection.query("SELECT * FROM agents")
            } catch {
                readError = error
            }

            readExpectation.fulfill()
        }

        DispatchQueue.userInitiated.asyncAfter(seconds: 0.01) {
            do {
                try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)
            } catch {
                writeError = error
            }

            writeExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(agents.count, 1_002)
        XCTAssertNil(readError)
        XCTAssertNil(writeError)
    }

    func testThatConnectionDoesNotThrowErrorWhenReadLockBlocksWriteLockUsingExecuteWithTableLockPolicyEnabled() throws {
        // Given
        let writeConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .poll(0.01),
            sharedCache: true
        )

        let readConnection = try Connection(
            storageLocation: storageLocation,
            tableLockPolicy: .poll(0.01),
            readOnly: true,
            sharedCache: true
        )

        try TestTables.insertDummyAgents(count: 1_000, connection: writeConnection)

        let writeExpectation = self.expectation(description: "Write should succeed")
        let readExpectation = self.expectation(description: "Read should succeed")

        var agents: [Agent] = []
        var writeError: Error?
        var readError: Error?

        // When
        DispatchQueue.userInitiated.async {
            do {
                agents = try readConnection.query("SELECT * FROM agents")
            } catch {
                readError = error
            }

            readExpectation.fulfill()
        }

        DispatchQueue.userInitiated.asyncAfter(seconds: 0.01) {
            do {
                let dateString = bindingDateFormatter.string(from: Date())

                let sql = """
                    INSERT INTO agents(name, date, missions, salary, job_title, car)
                    VALUES('name', '\(dateString)', 13.123, 20, '\("job".data(using: .utf8)!)', NULL)
                    """

                try writeConnection.execute(sql)
            } catch {
                writeError = error
            }

            writeExpectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(agents.count, 1_002)
        XCTAssertNil(readError)
        XCTAssertNil(writeError)
    }
}
