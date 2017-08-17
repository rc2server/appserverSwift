//
//  FileHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectLib
import Rc2Model

class FileHandler {
	let fileNameHeader = "Rc2-Filename"
	let settings: AppSettings
	
	init(settings: AppSettings) {
		self.settings = settings
	}
	
	func routes() -> [Route] {
		var routes = [Route]()
		routes.append(Route(method: .post, uri: "/file/create/{wspaceId}", handler: createFile))
		routes.append(Route(method: .put, uri: "/file/{fileId}", handler: uploadData))
		routes.append(Route(method: .get, uri: "/file/{fileId}", handler: downloadData))
		return routes
	}
	
	// create the sent file
	func createFile(request: HTTPRequest, response: HTTPResponse) {
		guard let wspaceIdStr = request.urlVariables["wspaceId"],
			let wspaceId = Int(wspaceIdStr),
			let filename = request.header(.custom(name: fileNameHeader)),
			filename.count > 2,
			let data = request.postBodyBytes
		else {
			handle(error: SessionError.fileNotFound, response: response)
			return
		}
		do {
			let file = try settings.dao.insertFile(name: filename, wspaceId: wspaceId, bytes: data)
			let data = try settings.encode(file)
			response.bodyBytes.removeAll()
			response.bodyBytes.append(contentsOf: Array<UInt8>(data))
			response.completed(status: .created)
		} catch {
			Log.logger.warning(message: "failed to save file contents: \(error)", true)
			handle(error: SessionError.databaseUpdateFailed, response: response)
		}
	}
	
	// update the content of the specified file
	func uploadData(request: HTTPRequest, response: HTTPResponse) {
		guard let fileIdStr = request.urlVariables["fileId"],
			let fileId = Int(fileIdStr),
			let userId = request.login?.userId,
			let data = request.postBodyBytes,
			let _ = (try? settings.dao.getFile(id: fileId, userId: userId)) as? Rc2Model.File
			else {
				handle(error: SessionError.fileNotFound, response: response)
				return
		}
		do {
			try settings.dao.setFile(bytes: data, fileId: fileId)
		} catch {
			Log.logger.warning(message: "failed to save file contents: \(error)", true)
			handle(error: SessionError.databaseUpdateFailed, response: response)
		}
	}
	
	/// send the contents of the requested file
	func downloadData(request: HTTPRequest, response: HTTPResponse) {
		guard let fileIdStr = request.urlVariables["fileId"],
			let fileId = Int(fileIdStr),
			let userId = request.login?.userId,
			let file = (try? settings.dao.getFile(id: fileId, userId: userId)) as? Rc2Model.File,
			let data = try? settings.dao.getFileData(fileId: fileId)
		else {
			handle(error: SessionError.invalidRequest, response: response)
			return
		}
		response.bodyBytes.removeAll()
		response.bodyBytes.append(contentsOf: data)
		let fname = file.name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "\(file.id)"
		response.setHeader(.contentDisposition, value: "attachment; filename = \"\(fname)\"")
		response.setHeader(.contentType, value: MimeType.forExtension("bin"))
		response.completed()
	}
	
	/// send the specified session error as json content with a 404 error
	private func handle(error: SessionError, response: HTTPResponse) {
		if let errorData = try? settings.encode(error) {
			response.bodyBytes.append(contentsOf: errorData)
			response.setHeader(.contentType, value: MimeType.forExtension("json"))
		}
		response.completed(status: .notFound)
	}
}
