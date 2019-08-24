//
//  StatusHandler.swift
//
//  Copyright ©2018 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectLib
import MJLLogger

class StatusHandler: BaseHandler {
	func routes() -> [Route] {
		var routes = [Route]()
		routes.append(Route(method: .get, uri: "/status", handler: liveCheck))
		routes.append(Route(method: .get, uri: settings.config.urlPrefixToIgnore + "/status", handler: liveCheck))
		routes.append(Route(method: .get, uri: settings.config.urlPrefixToIgnore + "/", handler: emptyResponse))
		routes.append(Route(method: .get, uri: "/", handler: emptyResponse))
		return routes
	}

	func emptyResponse(request: HTTPRequest, response: HTTPResponse) {
		response.setHeader(.contentType, value: MimeType.forExtension("html"))
		response.completed()
	}

    func liveCheck(request: HTTPRequest, response: HTTPResponse) {
        // always respond with 200 cause must be live if this handler is called
		response.bodyBytes.removeAll()
		let emptyJson: [UInt8] = Array("{}".utf8)
		response.bodyBytes.append(contentsOf: emptyJson)
		response.setHeader(.contentType, value: MimeType.forExtension("json"))
		response.completed()
    }
}
	
