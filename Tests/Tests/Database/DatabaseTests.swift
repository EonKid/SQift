//
//  DatabaseTests.swift
//  SQift
//
//  Created by Christian Noon on 11/17/15.
//  Copyright © 2015 Nike. All rights reserved.
//

import Foundation
import SQift
import SQLite3
import XCTest

class DatabaseTestCase: XCTestCase {
    private let storageLocation: StorageLocation = {
        let path = FileManager.cachesDirectory.appending("/database_tests.db")
        return .onDisk(path)
    }()

    // MARK: - Setup and Teardown

    override func tearDown() {
        super.tearDown()
        FileManager.removeItem(atPath: storageLocation.path)
    }

    // MARK: - Tests

    func testThatDatabaseCanBeInitializedWithAllStorageLocations() {
        // Given, When, Then
        do {
            let _ = try Database(storageLocation: storageLocation)
            let _ = try Database(storageLocation: .inMemory)
            let _ = try Database(storageLocation: .temporary)
            let _ = try Database(storageLocation: storageLocation, flags: SQLITE_OPEN_READONLY)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatDatabaseInitializationExecutesWriterConnectionPreparationClosure() {
        do {
            // Given
            let database = try Database(
                storageLocation: storageLocation,
                writerConnectionPreparation: { connection in
                    try connection.execute("PRAGMA foreign_keys = ON")
                    try connection.execute("PRAGMA synchronous = 1")
                }
            )

            var foreignKeys = 0
            var synchronous = 0

            // When
            try database.writerConnectionQueue.execute { connection in
                foreignKeys = try connection.query("PRAGMA foreign_keys")
                synchronous = try connection.query("PRAGMA synchronous")
            }

            // Then
            XCTAssertEqual(foreignKeys, 1, "foreign keys should be 1")
            XCTAssertEqual(synchronous, 1, "synchronous should be 1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatDatabaseFailsToInitializeWithInvalidOnDiskStorageLocation() {
        do {
            // Given, When
            let _ = try Database(storageLocation: .onDisk("/path/does/not/exist"))

            XCTFail("Execution should not reach this point")
        } catch let error as SQLiteError {
            // Then
            XCTAssertEqual(error.code, SQLITE_CANTOPEN, "error code should be `SQLITE_CANTOPEN`")
        } catch {
            XCTFail("Failed with an unknown error type: \(error)")
        }
    }

    func testThatDatabaseCanExecuteRead() {
        do {
            // Given, When, Then
            let database = try Database(storageLocation: storageLocation)

            // When
            var areValuesEqual = true

            try database.executeRead { connection in
                areValuesEqual = try connection.query("SELECT ? = ?", 1, 2)
            }

            // Then
            XCTAssertFalse(areValuesEqual)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatDatabaseCanExecuteWrite() {
        do {
            // Given, When, Then
            let database = try Database(storageLocation: storageLocation)

            // When
            var tableExists = false

            try database.executeWrite { connection in
                try connection.run("CREATE TABLE agent(name TEXT PRIMARY KEY)")
                tableExists = try connection.query("SELECT count(*) FROM sqlite_master WHERE type = ?", "table")
            }

            // Then
            XCTAssertTrue(tableExists)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}