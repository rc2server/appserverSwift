//
//  FileHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import MJLLogger
import Rc2Model

class FileHandler: BaseHandler {
	let fileNameHeader = "Rc2-Filename"

	func routes() -> [Route] {
		var routes = [Route]()
		routes.append(Route(method: .post, uri: settings.config.urlPrefixToIgnore + "/file/create/{wspaceId}", handler: createFile))
		routes.append(Route(method: .put, uri: settings.config.urlPrefixToIgnore + "/file/{fileId}", handler: uploadData))
		routes.append(Route(method: .get, uri: settings.config.urlPrefixToIgnore + "/file/{fileId}", handler: downloadData))
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
		Log.info("creating file \(filename) in wspace \(wspaceId)")
		do {
			let file = try settings.dao.insertFile(name: filename, wspaceId: wspaceId, bytes: data)
			let data = try settings.encode(file)
			response.bodyBytes.removeAll()
			response.bodyBytes.append(contentsOf:(data))
			response.completed(status: .created)
		} catch {
			Log.warn("failed to save file contents: \(error)")
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
		Log.info("updating file \(fileId)")
		do {
			try settings.dao.setFile(bytes: data, fileId: fileId)
			response.completed(status: .noContent)
		} catch {
			Log.warn("failed to save file contents: \(error)")
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
}
