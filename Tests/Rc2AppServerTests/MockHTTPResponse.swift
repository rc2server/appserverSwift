//
//  MockHTTPResponse.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectNet
import PerfectLib

class MockHTTPResponse: HTTPResponse {

	init(request: HTTPRequest, status: HTTPResponseStatus) {
		self.request = request
		self.status = status
	}
	
	var request: HTTPRequest
	
	var status: HTTPResponseStatus
	
	var isStreaming: Bool = false
	
	var bodyBytes: [UInt8] = []

	var headerStore = Array<(HTTPResponseHeader.Name, String)>()
	var headers: AnyIterator<(HTTPResponseHeader.Name, String)> {
		var g = self.headerStore.makeIterator()
		return AnyIterator<(HTTPResponseHeader.Name, String)> {
			g.next()
		}
	}

	func header(_ named: HTTPResponseHeader.Name) -> String? {
		for (n, v) in headerStore where n == named {
			return v
		}
		return nil
	}
	
	func addHeader(_ named: HTTPResponseHeader.Name, value: String) -> Self {
		headerStore.append((named, value))
		return self
	}
	
	func setHeader(_ named: HTTPResponseHeader.Name, value: String) -> Self {
		var fi = [Int]()
		for i in 0..<headerStore.count {
			let (n, _) = headerStore[i]
			if n == named {
				fi.append(i)
			}
		}
		fi = fi.reversed()
		for i in fi {
			headerStore.remove(at: i)
		}
		return addHeader(named, value: value)
	}
	
	func push(callback: @escaping (Bool) -> ()) {
		
	}
	
	func next() {
		
	}

	func completed() {
	}
}
