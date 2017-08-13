//
//  Row.swift
//  SQift
//
//  Created by Christian Noon on 11/8/15.
//  Copyright © 2015 Nike. All rights reserved.
//

import Foundation
import SQLite3

/// The `Row` struct represents a row returned by a database query. It uses numeric and text-based subscripts along with
/// internal generic methods to extract values from the database.
public struct Row {

    // MARK: Helper Types

    // TODO: docstring and tests
    public struct Column: CustomStringConvertible {
        // TODO: docstring
        public enum ColumnType: RawRepresentable {
            case integer
            case float
            case text
            case blob
            case null

            public var rawValue: Int32 {
                switch self {
                case .integer: return SQLITE_INTEGER
                case .float:   return SQLITE_FLOAT
                case .text:    return SQLITE_TEXT
                case .blob:    return SQLITE_BLOB
                case .null:    return SQLITE_NULL
                }
            }

            var name: String {
                switch self {
                case .integer: return "integer"
                case .float:   return "float"
                case .text:    return "text"
                case .blob:    return "blob"
                case .null:    return "null"
                }
            }

            public init(rawValue: Int32) {
                switch rawValue {
                case ColumnType.integer.rawValue: self = .integer
                case ColumnType.float.rawValue:   self = .float
                case ColumnType.text.rawValue:    self = .text
                case ColumnType.blob.rawValue:    self = .blob
                default:                          self = .null
                }
            }
        }

        public let index: Int
        public let name: String
        public let type: ColumnType
        public let value: Any?

        public var description: String {
            return "{ index: \(index) name: \"\(name)\", type: \"\(type)\", value: \(value ?? "nil") }"
        }
    }

    // MARK: Properties

    // TODO: test and docstring
    public var columnCount: Int { return statement.columnCount }

    // TODO: test and docstring
    public var columns: [Column] {
        return (0..<columnCount).map { index in
            Column(
                index: index,
                name: statement.columnName(at: index),
                type: Column.ColumnType(rawValue: statement.columnType(at: index)),
                value: value(at: index)
            )
        }
    }

    private let statement: Statement
    private var handle: OpaquePointer { return statement.handle }

    // MARK: Initialization

    init(statement: Statement) {
        self.statement = statement
    }

    /// Returns an `Extractable` instance at the given column index.
    ///
    /// - Parameter columnIndex: The index of the column of the value to extract.
    ///
    /// - Returns: The non-optional value of the column at the specified index.
    public subscript<T: Extractable>(columnIndex: Int) -> T { return value(at: columnIndex)! }

    /// Returns an optional `Extractable` instance at the given column index.
    ///
    /// - Parameter columnIndex: The index of the column of the value to extract.
    ///
    /// - Returns: The value of the column at the specified index if it exists, `nil` otherwise.
    public subscript<T: Extractable>(columnIndex: Int) -> T? { return value(at: columnIndex) }

    /// Returns an `Extractable` instance for the column index matching the specified name.
    ///
    /// - Parameter columnName: The name of the column of the value to extract.
    ///
    /// - Returns: The non-optional value of the column with the specified column name.
    public subscript<T: Extractable>(columnName: String) -> T { return value(forColumnName: columnName)! }

    /// Returns an optional `Extractable` instance for the column index matching the specified name.
    ///
    /// - Parameter columnName: The name of the column of the value to extract.
    ///
    /// - Returns: The optional value of the column with the specified column name if it exists, `nil` otherwise.
    public subscript<T: Extractable>(columnName: String) -> T? { return value(forColumnName: columnName) }

    // MARK: Values

    /// Returns the value at the given column index as an optional `Any` object.
    ///
    /// The value extraction logic uses the `sqlite3_column_type` method to determine what the underlying data type
    /// is at the column index location in the database. It then uses one of the four following functions to extract
    /// the data as the correct type:
    ///
    ///     - sqlite3_column_int64:  `INTEGER` binding value.
    ///     - sqlite3_column_double: `REAL` binding value.
    ///     - sqlite3_column_text:   `TEXT` binding value.
    ///     - sqlite3_column_blob:   `BLOB` binding value.
    ///
    /// For more information, please refer to the [documentation](https://www.sqlite.org/c3ref/column_blob.html).
    ///
    /// - Parameter columnIndex: The column index to extract the value from.
    ///
    /// - Returns: The value at the specified column index.
    public func value(at columnIndex: Int) -> Any? {
        var value: Any?

        switch statement.columnType(at: columnIndex) {
        case SQLITE_NULL:
            value = nil

        case SQLITE_INTEGER:
            value = sqlite3_column_int64(handle, Int32(columnIndex))

        case SQLITE_FLOAT:
            value = sqlite3_column_double(handle, Int32(columnIndex))

        case SQLITE_TEXT:
            value = String(cString: sqlite3_column_text(handle, Int32(columnIndex)))

        case SQLITE_BLOB:
            guard let bytes = sqlite3_column_blob(handle, Int32(columnIndex)) else { break }
            let count = Int(sqlite3_column_bytes(handle, Int32(columnIndex)))

            value = Data(bytes: bytes, count: count)

        default:
            break
        }

        return value
    }

    /// Returns the value at the specified column index as the optional `Binding.DataType`.
    ///
    /// - Parameter columnIndex: The column index to extract the value from.
    ///
    /// - Returns: The value at the specified column index.
    public func value<T: Extractable>(at columnIndex: Int) -> T? {
        let value = self.value(at: columnIndex)
        guard let bindingValue = value as? T.BindingType else { return nil }

        return T.fromBindingValue(bindingValue) as? T
    }

    /// Returns the value at the column index matching the specified name as the optional `Binding.DataType`.
    ///
    /// - Parameter columnName: The column name to extract the value from.
    ///
    /// - Returns: The value at the column index matching the specified name.
    public func value<T: Extractable>(forColumnName columnName: String) -> T? {
        guard let columnIndex = statement.columnIndex(forName: columnName) else { return nil }
        let value = self.value(at: columnIndex)

        guard let bindingValue = value as? T.BindingType else { return nil }

        return T.fromBindingValue(bindingValue) as? T
    }
}

// MARK: - Sequence

extension Row: Sequence {
    /// Returns all values in the `Row` for every column as an array of optional `Any` object.
    public var values: [Any?] { return map { $0 } }

    /// Returns an `AnyIterator` satisfying the conformance requirements of the `Sequence` protocol.
    public func makeIterator() -> AnyIterator<Any?> {
        var currentIndex = 0
        let statement = self.statement

        return AnyIterator {
            guard currentIndex < statement.columnCount else { return nil }

            let value = self.value(at: currentIndex)
            currentIndex += 1

            return value
        }
    }
}

// MARK: - CustomStringConvertible

extension Row: CustomStringConvertible {
    /// A textual description of the `Row` values.
    public var description: String {
        let stringValues: [String] = values.map { value in
            if let value = value as? String {
                return "'\(value)'"
            } else if let value = value {
                return String(describing: value)
            } else {
                return "NULL"
            }
        }

        return "[" + stringValues.joined(separator: ", ") + "]"
    }
}

// MARK: - ExpressibleByRow

/// A type that can be initialized using a row.
public protocol ExpressibleByRow {
    /// Creates an instance using the specified row.
    ///
    /// - Parameter row: The row to use for initialization.
    init(row: Row) throws
}