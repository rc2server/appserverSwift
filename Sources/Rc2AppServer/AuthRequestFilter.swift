//
//  AuthRequestFilter.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTPServer
import PerfectHTTP
import PerfectCrypto
import servermodel
import MJLLogger

fileprivate let psecret = "32342fsa"

class AuthRequestFilter: HTTPRequestFilter {
	private let tokenDAO: LoginTokenDAO
	private let settings: AppSettings
	private let loginPath: String
	
	init(dao: LoginTokenDAO, settings: AppSettings) {
		tokenDAO = dao
		self.settings = settings
		loginPath = settings.config.urlPrefixToIgnore + "/login"
		Log.debug("login path=\(loginPath)")
	}
	
	func filter(request: HTTPRequest, response: HTTPResponse, callback: (HTTPRequestFilterResult) -> ()) {
		// filter doesn't apply to login and logout
		guard request.path != loginPath else {
			Log.debug("skipping auth for /login")
			callback(.continue(request, response))
			return
		}
		Log.debug("authenticating for \(request.path)")
		// find the authorization header
		guard let rawHeader = request.header(.authorization) else {
			Log.debug("failed to find auth header")
			response.completed(status: .forbidden)
			callback(.halt(request, response))
			return
		}
		//extract the bearer token
		let prefix = "Bearer "
		let tokenIndex = rawHeader.index(rawHeader.startIndex, offsetBy: prefix.count)
		let token = String(rawHeader[tokenIndex...])
		Log.debug("auth found token \(token)")
		// parse and verify the token
		guard let verifier = JWTVerifier(token),
			let _ = try? verifier.verify(algo: .hs256, key: psecret),
			let loginToken = LoginToken(verifier.payload),
			tokenDAO.validate(token: loginToken)
			else {
				Log.info("token failed validation")
				response.completed(status: .forbidden)
				callback(.halt(request, response))
				return
			}
		//we have a valid token
		request.login = loginToken
		callback(.continue(request, response))
	}
}
