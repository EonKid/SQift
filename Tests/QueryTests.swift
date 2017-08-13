//
//  QueryTests.swift
//  SQift
//
//  Created by Christian Noon on 11/12/15.
//  Copyright © 2015 Nike. All rights reserved.
//

import Foundation
import SQift
import XCTest

class QueryTestCase: XCTestCase {

    // MARK: - Properties

    private var connection: Connection!

    private let storageLocation: StorageLocation = {
        let path = FileManager.cachesDirectory.appending("/query_tests.db")
        return .onDisk(path)
    }()

    private let archer = Agent(
        id: 1,
        name: "Sterling Archer",
        date: bindingDateFormatter.date(from: "2015-10-02T08:20:00.000")!,
        missions: 485,
        salary: 2_500_000.56,
        jobTitle: "The world's greatest secret agent".data(using: .utf8)!,
        car: "Charger"
    )

    private let lana = Agent(
        id: 2,
        name: "Lana Kane",
        date: bindingDateFormatter.date(from: "2015-11-06T08:00:00.000")!,
        missions: 2_315,
        salary: 9_600_200.11,
        jobTitle: "Top Agent".data(using: .utf8)!,
        car: nil
    )

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        FileManager.removeItem(atPath: storageLocation.path)

        do {
            connection = try Connection(storageLocation: storageLocation)
            try TestTables.createAndPopulateAgentsTable(using: connection)
        } catch {
            // No-op
        }
    }

    // MARK: - Tests - Query APIs

    func testThatConnectionCanQueryExtractable() {
        do {
            // Given, When
            let totalMissions: Int = try connection.query("SELECT sum(missions) FROM agents")
            let name: String = try connection.query("SELECT name FROM agents WHERE car = ?", "Charger")
            let salary: Double = try connection.query("SELECT salary FROM agents WHERE car = ?", parameters: ["Charger"])
            let id: Int = try connection.query("SELECT id FROM agents WHERE car = :car", parameters: [":car": "Charger"])

            // Then
            XCTAssertEqual(totalMissions, 2_800)
            XCTAssertEqual(name, "Sterling Archer")
            XCTAssertEqual(salary, 2_500_000.56)
            XCTAssertEqual(id, 1)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryExtractableOptional() {
        do {
            // Given, When
            let totalMissions: Int? = try connection.query("SELECT sum(missions) FROM agents")
            let name: String? = try connection.query("SELECT name FROM agents WHERE car = ?", "Charger")
            let salary: Double? = try connection.query("SELECT salary FROM agents WHERE car = ?", parameters: ["Charger"])
            let id: Int? = try connection.query("SELECT id FROM agents WHERE car = :car", parameters: [":car": "Charger"])
            let car: String? = try connection.query("SELECT car FROM agents WHERE name = ?", "Lana Kane")

            // Then
            XCTAssertEqual(totalMissions, 2_800)
            XCTAssertEqual(name, "Sterling Archer")
            XCTAssertEqual(salary, 2_500_000.56)
            XCTAssertEqual(id, 1)
            XCTAssertEqual(car, nil)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryRow() {
        do {
            // Given, When
            let row1: Row? = try connection.query("SELECT name FROM agents WHERE car IS NULL")
            let row2: Row? = try connection.query("SELECT id, name, missions FROM agents WHERE car = ?", "Charger")
            let row3: Row? = try connection.query("SELECT salary FROM agents WHERE car = ?", parameters: ["Charger"])
            let row4: Row? = try connection.query("SELECT * FROM agents WHERE car = :car", parameters: [":car": "Charger"])

            // Then
            XCTAssertEqual(row1?.columnCount, 1)
            XCTAssertEqual(row1?.columns.count, 1)

            XCTAssertEqual(row2?.columnCount, 3)
            XCTAssertEqual(row2?.columns.count, 3)

            XCTAssertEqual(row3?.columnCount, 1)
            XCTAssertEqual(row3?.columns.count, 1)

            XCTAssertEqual(row4?.columnCount, 7)
            XCTAssertEqual(row4?.columns.count, 7)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryExpressibleByRow() {
        do {
            // Given, When
            let lana1: Agent? = try connection.query("SELECT * FROM agents WHERE car IS NULL")
            let archer1: Agent? = try connection.query("SELECT * FROM agents WHERE car = ?", "Charger")
            let archer2: Agent? = try connection.query("SELECT * FROM agents WHERE car = ?", parameters: ["Charger"])
            let archer3: Agent? = try connection.query("SELECT * FROM agents WHERE car = :car", parameters: [":car": "Charger"])

            // Then
            XCTAssertEqual(lana1, lana)
            XCTAssertEqual(archer1, archer)
            XCTAssertEqual(archer2, archer)
            XCTAssertEqual(archer3, archer)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryT() {
        do {
            // Given
            let sql1 = "SELECT * FROM agents WHERE car = ?"
            let sql2 = "SELECT * FROM agents WHERE car = :car"

            // When
            let lana1: Agent? = try connection.query("SELECT * FROM agents WHERE car IS NULL") { try Agent(row: $0) }
            let archer1: Agent? = try connection.query(sql1, "Charger") { try Agent(row: $0) }
            let archer2: Agent? = try connection.query(sql1, parameters: ["Charger"]) { try Agent(row: $0) }
            let archer3: Agent? = try connection.query(sql2, parameters: [":car": "Charger"]) { try Agent(row: $0) }

            // Then
            XCTAssertEqual(lana1, lana)
            XCTAssertEqual(archer1, archer)
            XCTAssertEqual(archer2, archer)
            XCTAssertEqual(archer3, archer)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryExtractableArray() {
        do {
            // Given, When
            let ids: [Int] = try connection.query("SELECT id FROM agents")
            let names: [String] = try connection.query("SELECT name FROM agents WHERE car IS NULL OR car != ?", "Honda")
            let salaries: [Double] = try connection.query("SELECT salary FROM agents WHERE salary > ?", parameters: [100_000])
            let cars: [String] = try connection.query("SELECT car FROM agents WHERE car IS NULL OR car != :car", parameters: [":car": "Honda"])

            // Then
            XCTAssertEqual(ids, [1, 2])
            XCTAssertEqual(names, ["Sterling Archer", "Lana Kane"])
            XCTAssertEqual(salaries, [2_500_000.56, 9_600_200.11])
            XCTAssertEqual(cars, ["Charger"])
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryExpressibleByRowArray() {
        do {
            // Given, When
            let agents1: [Agent] = try connection.query("SELECT * FROM agents")
            let agents2: [Agent] = try connection.query("SELECT * FROM agents WHERE missions > ?", 500)
            let agents3: [Agent] = try connection.query("SELECT * FROM agents WHERE missions > ?", parameters: [1])
            let agents4: [Agent] = try connection.query("SELECT * FROM agents WHERE missions < :missions", parameters: [":missions": 2000])

            // Then
            XCTAssertEqual(agents1, [archer, lana])
            XCTAssertEqual(agents2, [lana])
            XCTAssertEqual(agents3, [archer, lana])
            XCTAssertEqual(agents4, [archer])
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryTArray() {
        do {
            // Given
            let sql1 = "SELECT * FROM agents WHERE car = ?"
            let sql2 = "SELECT * FROM agents WHERE car = :car"

            // When
            let agents1: [Agent] = try connection.query("SELECT * FROM agents") { try Agent(row: $0) }
            let agents2: [Agent] = try connection.query(sql1, "Charger") { try Agent(row: $0) }
            let agents3: [Agent] = try connection.query(sql1, parameters: ["Charger"]) { try Agent(row: $0) }
            let agents4: [Agent] = try connection.query(sql2, parameters: [":car": "Charger"]) { try Agent(row: $0) }

            // Then
            XCTAssertEqual(agents1, [archer, lana])
            XCTAssertEqual(agents2, [archer])
            XCTAssertEqual(agents3, [archer])
            XCTAssertEqual(agents4, [archer])
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryDictionary() {
        do {
            // Given
            let sql1 = "SELECT name, missions FROM agents WHERE missions > ?"
            let sql2 = "SELECT name, missions FROM agents WHERE missions > :missions"

            // When
            let cars: [String: String?] = try connection.query("SELECT name, car FROM agents") { ($0[0], $0[1]) }
            let missions1: [String: Int] = try connection.query(sql1, 10) { ($0[0], $0[1]) }
            let missions2: [String: Int] = try connection.query(sql1, parameters: [10]) { ($0[0], $0[1]) }
            let missions3: [String: Int] = try connection.query(sql2, parameters: [":missions": 10]) { ($0[0], $0[1]) }

            // Then
            XCTAssertEqual(cars.count, 2)
            XCTAssertEqual(cars["Sterling Archer"] as? String, "Charger")
            XCTAssertEqual(cars["Lana Kane"] as? String, nil)

            XCTAssertEqual(missions1.count, 2)
            XCTAssertEqual(missions1["Sterling Archer"], 485)
            XCTAssertEqual(missions1["Lana Kane"], 2_315)

            XCTAssertEqual(missions2.count, 2)
            XCTAssertEqual(missions2["Sterling Archer"], 485)
            XCTAssertEqual(missions2["Lana Kane"], 2_315)

            XCTAssertEqual(missions3.count, 2)
            XCTAssertEqual(missions3["Sterling Archer"], 485)
            XCTAssertEqual(missions3["Lana Kane"], 2_315)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanQueryDictionaryWithResultInjection() {
        do {
            // Given
            let sql1 = "SELECT name, missions FROM agents WHERE missions > ?"
            let sql2 = "SELECT name, missions FROM agents WHERE missions > :missions"

            // When
            let missions1: [Int: [String: Int]] = try connection.query("SELECT name, missions FROM agents") { results, row in
                var result = results[1] ?? [:]
                result[row[0]] = row[1]
                return (1, result)
            }

            let missions2: [Int: [String: Int]] = try connection.query(sql1, 10) { results, row in
                var result = results[1] ?? [:]
                result[row[0]] = row[1]
                return (1, result)
            }

            let missions3: [Int: [String: Int]] = try connection.query(sql1, parameters: [10]) { results, row in
                var result = results[1] ?? [:]
                result[row[0]] = row[1]
                return (1, result)
            }

            let missions4: [Int: [String: Int]] = try connection.query(sql2, parameters: [":missions": 10]) { results, row in
                var result = results[1] ?? [:]
                result[row[0]] = row[1]
                return (1, result)
            }

            // Then
            for missions in [missions1, missions2, missions3, missions4] {
                XCTAssertEqual(missions.count, 1)

                if missions.count == 1 {
                    XCTAssertEqual(missions[1]?.count, 2)
                    XCTAssertEqual(missions[1]?["Sterling Archer"], 485)
                    XCTAssertEqual(missions[1]?["Lana Kane"], 2_315)
                }
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}
