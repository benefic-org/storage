//
// Copyright © 2021 Benefic Technologies Inc. All rights reserved.
// License Information: https://github.com/oxcug/hex/blob/master/LICENSE

import XCTest

import StorageTests

var tests = [XCTestCaseEntry]()
tests += HexStorageTests.__allTests()

XCTMain(tests)
