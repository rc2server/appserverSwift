//
//  AuthManager.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import servermodel
import PerfectHTTP
import PerfectCrypto
import Freddy

fileprivate let psecret = "32342fsa"

class AuthManager {
	let dao: Rc2DAO
	let tokenDao: LoginTokenDAO
	
	init(dao: Rc2DAO) {
		self.dao = dao
		self.tokenDao = dao.createTokenDAO()
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
			let jsonString = request.postBodyString
			else {
				response.setBody(string: "json required")
				response.completed(status: .badRequest)
				return
		}
		do {
			let json = try JSON(jsonString: jsonString)
			let login = try json.getString(at: "user")
			let password = try json.getString(at: "password")
			guard let user = try self.dao.getUser(login: login, password: password) else {
				//invalid login
				response.setBody(string: "invalid login or password")
				response.completed(status: .unauthorized)
				return
			}
			//figure out JWT
			let loginToken = try tokenDao.createToken(user: user)
			guard let encoder = JWTCreator(payload: loginToken.contents) else {
				//failed to encrypt password
				print("failed to create jwt")
				response.completed(status: .internalServerError)
				return
			}
			let token = try encoder.sign(alg: .hs256, key: psecret)
			//send json data
			let responseJson = JSON(["token": .string(token)])
			response.setBody(string: try responseJson.serializeString())
			response.addHeader(.contentEncoding, value: jsonType)
			response.completed()
			return
		} catch {
			print("invalid login json \(error)")
			response.completed(status: .badRequest)
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
}
