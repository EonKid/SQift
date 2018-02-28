//
//  TableLockErrorPolicy.swift
//
//  Copyright 2015-present, Nike, Inc.
//  All rights reserved.
//
//  This source code is licensed under the BSD-stylelicense found in the LICENSE
//  file in the root directory of this source tree.
//

import Foundation

public enum TableLockErrorPolicy {
    case on(delay: TimeInterval)
    case off

    public static var `default`: TableLockErrorPolicy {
        return .on(delay: 0.01) // 10 ms
    }

    var isEnabled: Bool {
        if case .on = self { return true }
        return false
    }

    var isDisabled: Bool { return !isEnabled }

    var delay: TimeInterval? {
        switch self {
        case .on(let delay): return delay
        case .off:           return nil
        }
    }

    var delayInMicroseconds: UInt32? {
        guard let delay = delay else { return nil }
        return UInt32(exactly: delay * 1_000_000)
    }
}
