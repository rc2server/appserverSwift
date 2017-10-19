//
//  AuthManager.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import servermodel
import PerfectHTTP
import PerfectCrypto
import LoggerAPI

fileprivate let psecret = "32342fsa"

class AuthManager: BaseHandler {
	let tokenDao: LoginTokenDAO
	
	override init(settings: AppSettings) {
		self.tokenDao = settings.dao.createTokenDAO()
		super.init(settings: settings)
	}
	
	func authRoutes() -> [Route] {
		var routes = [Route]()
		routes.append(Route(method: .post, uri: "/login", handler: login))
		routes.append(Route(method: .delete, uri: "/login", handler: logout))
		return routes
	}
	
	func login(request: HTTPRequest, response: HTTPResponse) {
		//make sure we were sent json
		guard request.header(.contentType) == jsonType,
			let jsonBytes = request.postBodyBytes
			else {
				Log.info("login request w/o json")
				response.setBody(string: "json required")
				response.completed(status: .badRequest)
				return
		}
		do {
			let params: LoginParams = try settings.decode(data: Data(Array.init(jsonBytes)))
			Log.info("attempting login for '\(params.login)' using '\(params.password)'")
			guard let user = try self.settings.dao.getUser(login: params.login, password: params.password) else {
				//invalid login
				Log.info("invalid login for \(params.login)")
				response.setBody(string: "invalid login or password")
				response.completed(status: .unauthorized)
				return
			}
			//figure out JWT
			let loginToken = try tokenDao.createToken(user: user)
			guard let encoder = JWTCreator(payload: loginToken.contents) else {
				//failed to encrypt password
				Log.warning("failed to create jwt")
				response.completed(status: .internalServerError)
				return
			}
			let token = try encoder.sign(alg: .hs256, key: psecret)
			//send json data
			let responseData = try settings.encode(LoginResponse(token: token))
			response.bodyBytes.append(contentsOf: responseData.makeBytes())
			response.addHeader(.contentEncoding, value: jsonType)
			response.completed()
			return
		} catch {
			Log.warning("invalid login json \(error)")
			response.completed(status: .unauthorized)
			return
		}		
	}
	
	func logout(request: HTTPRequest, response: HTTPResponse) {
		guard let token = request.login else {
			response.completed(status: .badRequest)
			return
		}
		_ = try? tokenDao.invalidate(token: token)
		response.completed()
	}
	
	struct LoginParams: Codable {
		let login: String
		let password: String
	}
	
	struct LoginResponse: Codable {
		let token: String
	}
}
