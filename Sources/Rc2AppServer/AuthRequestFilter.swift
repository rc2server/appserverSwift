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

fileprivate let psecret = "32342fsa"

class AuthRequestFilter: HTTPRequestFilter {
	private let tokenDAO: LoginTokenDAO
	
	init(dao: LoginTokenDAO) {
		tokenDAO = dao
	}
	
	func filter(request: HTTPRequest, response: HTTPResponse, callback: (HTTPRequestFilterResult) -> ()) {
		// filter doesn't apply to login and logout
		guard request.path != "/login" else {
			callback(.continue(request, response))
			return
		}
		// find the authorization header
		guard let rawHeader = request.header(.authorization) else {
			response.completed(status: .forbidden)
			callback(.halt(request, response))
			return
		}
		//extract the bearer token
		let prefix = "Bearer "
		let tokenIndex = rawHeader.index(rawHeader.startIndex, offsetBy: prefix.count)
		let token = String(rawHeader[tokenIndex...])
		print("token \(token)")
		// parse and verify the token
		guard let verifier = JWTVerifier(token),
			let _ = try? verifier.verify(algo: .hs256, key: psecret),
			let loginToken = LoginToken(verifier.payload),
			tokenDAO.validate(token: loginToken)
			else {
				response.completed(status: .forbidden)
				callback(.halt(request, response))
				return
			}
		//we have a valid token
		request.login = loginToken
		callback(.continue(request, response))
	}
}
