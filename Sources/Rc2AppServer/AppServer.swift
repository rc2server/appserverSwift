//
//  AppServer.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import servermodel
import CommandLineKit
import PerfectWebSockets

public let jsonType = "application/json"

open class AppServer {
	public enum Errors: Error {
		case invalidDataDirectory
	}
	let server = HTTPServer()
	var requestFilters = [(HTTPRequestFilter, HTTPFilterPriority)]()
	var routes = [Route]()
	private(set) var dao: Rc2DAO!
	private var authManager: AuthManager!
	private var dataDirURL: URL!
	private var settings: AppSettings!
	private var sessionHandler: SessionHandler!
	private var websocketHandler: WebSocketHandler!
	private var fileHandler: FileHandler!
	private var infoHandler: InfoHandler!

	/// creates a server with the authentication filter installed
	public init() {
	}
	
	/// returns the default routes for the application
	public func defaultRoutes() -> [Route] {
		var defRoutes = [Route]()
		defRoutes.append(contentsOf: authManager.authRoutes())
		defRoutes.append(contentsOf: fileHandler.routes())
		defRoutes.append(contentsOf: infoHandler.routes())

		defRoutes.append(Route(method: .get, uri: "/ws/{wsId}") { request, response in
			self.websocketHandler.handleRequest(request: request, response: response)
		})
		
		return defRoutes
	}
	
	func parseCommandLine() {
		let cli = CommandLine()
		let dataDir = StringOption(shortFlag: "D", longFlag: "datadir", required: true, helpMessage: "Specify path to directory with data files")
		cli.addOption(dataDir)
		do {
			try cli.parse()
			dataDirURL = URL(fileURLWithPath: dataDir.value!)
			guard dataDirURL.hasDirectoryPath else { throw Errors.invalidDataDirectory }
		} catch {
			cli.printUsage(error)
			exit(EX_USAGE)
		}
	}
	
	/// Starts the server. Adds any filters. If routes have been added, only adds those routes. If no routes were added, then adds defaultRoutes()
	public func start() {
		dao = Rc2DAO()
		parseCommandLine()
		settings = AppSettings(dataDirURL: dataDirURL, dao: dao)

		do {
			try dao.connect(host: settings.config.dbHost, user: "rc2", database: "rc2")
			authManager = AuthManager(dao: dao)
			fileHandler = FileHandler(settings: settings)
			infoHandler = InfoHandler(settings: settings)
		} catch {
			print("failed to connect to database \(error)")
			exit(1)
		}
		requestFilters.append((AuthRequestFilter(dao: dao.createTokenDAO()), .high))

		server.setRequestFilters(requestFilters)
		sessionHandler = SessionHandler(settings: settings)
		websocketHandler = WebSocketHandler() { [weak self] (request: HTTPRequest, protocols: [String]) -> WebSocketSessionHandler? in
			return self?.sessionHandler
		}
		// jump through this hoop to allow dependency injection of routes
		var robj = Routes()
		if routes.count > 0 {
			robj.add(routes)
		} else {
			robj.add(defaultRoutes())
		}
		server.addRoutes(robj)
		server.serverPort = 8181

		do {
			// Launch the HTTP server on port 8181
			try server.start()
		} catch PerfectError.networkError(let err, let msg) {
			print("Network error thrown: \(err) \(msg)")
		} catch {
			print("unknown error: \(error)")
		}
	}
}
