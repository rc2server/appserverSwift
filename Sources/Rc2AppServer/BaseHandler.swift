//
//  BaseHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectLib
import Rc2Model

class BaseHandler {
	let settings: AppSettings
	
	init(settings: AppSettings) {
		self.settings = settings
	}
	
	/// send the specified session error as json content with a 404 error
	func handle(error: SessionError, response: HTTPResponse) {
		if let errorData = try? settings.encode(error) {
			response.bodyBytes.append(contentsOf: errorData)
			response.setHeader(.contentType, value: MimeType.forExtension("json"))
		}
		response.completed(status: .notFound)
	}
}

