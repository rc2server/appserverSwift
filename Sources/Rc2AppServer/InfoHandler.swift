//
//  InfoHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectLib
import Rc2Model

class InfoHandler: BaseHandler {
	func routes() -> [Route] {
		var routes = [Route]()
		routes.append(Route(method: .get, uri: "/info", handler: getBulkInfo))
		return routes
	}
	
	// return bulk info for logged in user
	func getBulkInfo(request: HTTPRequest, response: HTTPResponse) {
		do {
			guard let userId = request.login?.userId,
				let user = try settings.dao.getUser(id: userId)
			else {
				handle(error: SessionError.invalidRequest, response: response)
				return
			}
			let bulkInfo = try settings.dao.getUserInfo(user: user)
			response.bodyBytes.removeAll()
			response.bodyBytes.append(contentsOf: try settings.encode(bulkInfo))
			response.setHeader(.contentType, value: MimeType.forExtension("json"))
			response.completed()
		} catch {
			response.completed(status: .notFound)
		}
	}
}

