//
//  MockHTTPRequest.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectNet
import PerfectLib

class MockHTTPRequest: HTTPRequest {
	var remoteAddress: (host: String, port: UInt16) = ("", 0)
	
	var serverAddress: (host: String, port: UInt16) = ("", 0)
	
	var postBodyBytes: [UInt8]? = nil
	
	var postBodyString: String? = nil
	
	
	init() {
		let fd = open("/dev/random", O_RDONLY)
		connection = NetTCP(fd: fd)
	}
	
	var method = HTTPMethod.get
	
	var path = ""
	
	var pathComponents = [String]()
	
	var queryParams = [(String, String)]()
	
	var protocolVersion = (1, 0)
	
	var serverName = "localhost"
	
	var documentRoot = ".webroot"
	
	var connection: NetTCP
	
	var urlVariables = [String : String]()
	
	var scratchPad = [String : Any]()
	
	func header(_ named: HTTPRequestHeader.Name) -> String? {
		guard let v = headerStore[named] else {
			return nil
		}
		return UTF8Encoding.encode(bytes: v)
	}
	
	func addHeader(_ named: HTTPRequestHeader.Name, value: String) {
		guard let existing = headerStore[named] else {
			self.headerStore[named] = [UInt8](value.utf8)
			return
		}
		let valueBytes = [UInt8](value.utf8)
		let newValue: [UInt8]
		if named == .cookie {
			newValue = existing + "; ".utf8 + valueBytes
		} else {
			newValue = existing + ", ".utf8 + valueBytes
		}
		self.headerStore[named] = newValue
	}
	
	func setHeader(_ named: HTTPRequestHeader.Name, value: String) {
		headerStore[named] = [UInt8](value.utf8)
	}
	
	var postParams = [(String, String)]()
	
	var postFileUploads: [MimeReader.BodySpec]? = nil
	
	private var headerStore = Dictionary<HTTPRequestHeader.Name, [UInt8]>()
	
	var headers: AnyIterator<(HTTPRequestHeader.Name, String)> {
		var g = self.headerStore.makeIterator()
		return AnyIterator<(HTTPRequestHeader.Name, String)> {
			guard let n = g.next() else {
				return nil
			}
			return (n.key, UTF8Encoding.encode(bytes: n.value))
		}
	}

}
