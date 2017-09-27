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
// sysexits.h is not part of linux
#if os(Linux)
	let EX_USAGE: Int32 = 64
#endif

open class AppServer {
	public enum Errors: Error {
		case invalidDataDirectory
	}
	let server = HTTPServer()
	var requestFilters = [(HTTPRequestFilter, HTTPFilterPriority)]()
	var routes = [Route]()
	private var listenPort = 8088
	private(set) var dao: Rc2DAO!
	private var authManager: AuthManager!
	private var dataDirURL: URL!
	private var settings: AppSettings!
	private var sessionHandler: SessionHandler!
	private var websocketHandler: WebSocketHandler!
	private var fileHandler: FileHandler!
	private var infoHandler: InfoHandler!
	private var modelHandler: ModelHandler!

	/// creates a server with the authentication filter installed
	public init() {
	}
	
	/// returns the default routes for the application
	public func defaultRoutes() -> [Route] {
		var defRoutes = [Route]()
		defRoutes.append(contentsOf: authManager.authRoutes())
		defRoutes.append(contentsOf: fileHandler.routes())
		defRoutes.append(contentsOf: infoHandler.routes())
		defRoutes.append(contentsOf: modelHandler.routes())

		defRoutes.append(Route(method: .get, uri: "/ws/{wsId}") { request, response in
			self.websocketHandler.handleRequest(request: request, response: response)
		})
		
		return defRoutes
	}
	
	func parseCommandLine() {
		let cli = CommandLine()
		let dataDir = StringOption(shortFlag: "D", longFlag: "datadir", required: true, helpMessage: "Specify path to directory with data files")
		cli.addOption(dataDir)
		let portOption = IntOption(shortFlag: "p", helpMessage: "Port to listen to (defaults to 8088)")
		cli.addOption(portOption)
		do {
			try cli.parse()
			dataDirURL = URL(fileURLWithPath: dataDir.value!)
			guard dataDirURL.hasDirectoryPath else { throw Errors.invalidDataDirectory }
			if let pvalue = portOption.value { listenPort = pvalue }
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
			authManager = AuthManager(settings: settings)
			fileHandler = FileHandler(settings: settings)
			infoHandler = InfoHandler(settings: settings)
			modelHandler = ModelHandler(settings: settings)
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
		server.serverPort = UInt16(listenPort)

		do {
			// Launch the HTTP server
			try server.start()
		} catch PerfectError.networkError(let err, let msg) {
			print("Network error thrown: \(err) \(msg)")
		} catch {
			print("unknown error: \(error)")
		}
	}
}
