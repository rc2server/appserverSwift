//
//  HTTP11Request+Rc2.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import servermodel

public extension HTTPRequest {
	var login: LoginToken? {
		get { return scratchPad["login"] as? LoginToken }
		set { scratchPad["login"] = newValue }
	}
}
