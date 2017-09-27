//
//  ModelHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectHTTP
import PerfectLib
import PerfectZip
import Rc2Model

class ModelHandler: BaseHandler {
	private enum Errors: Error {
		case unzipError
	}

	func routes() -> [Route] {
		var routes = [Route]()
		routes.append(Route(method: .post, uri: "/proj/{projId}/wspace", handler: createWorkspace))
		return routes
	}
	
	// return bulk info for logged in user
	func createWorkspace(request: HTTPRequest, response: HTTPResponse) {
		do {
			guard let userId = request.login?.userId,
				let user = try settings.dao.getUser(id: userId),
				let projectIdStr = request.urlVariables["projId"],
				let projectId = Int(projectIdStr),
				let wspaceName = request.header(.custom(name: "Rc2-WorkspaceName")),
				wspaceName.count > 1,
				let project = try settings.dao.getProject(id: projectId),
				project.userId == userId
			else {
					handle(error: SessionError.invalidRequest, response: response)
					return
			}
			let wspaces = try settings.dao.getWorkspaces(project: project)
			guard wspaces.filter({ $0.name == wspaceName }).count == 0 else {
				handle(error: SessionError.duplicate, response: response)
				return
			}
			var zipUrl: URL? // will be set to the folder of uncompressed files for later deletion
			var fileUrls: [URL]? // urls of the files in the zipUrl
			if let uploadUrl = try unpackFiles(request: request) {
				zipUrl = uploadUrl
				fileUrls = try FileManager.default.contentsOfDirectory(at: uploadUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
			}
			defer { if let zipUrl = zipUrl { try? FileManager.default.removeItem(at: zipUrl) } }
			let wspace = try settings.dao.createWorkspace(project: project, name: wspaceName, insertingFiles: fileUrls)
			let bulkInfo = try settings.dao.getUserInfo(user: user)
			let result = CreateWorkspaceResult(wspaceId: wspace.id, bulkInfo: bulkInfo)
			response.bodyBytes.removeAll()
			response.bodyBytes.append(contentsOf: try settings.encode(result))
			response.setHeader(.contentType, value: MimeType.forExtension("json"))
			response.completed(status: .created)
		} catch {
			response.completed(status: .notFound)
		}
	}

	private func unpackFiles(request: HTTPRequest) throws -> URL? {
		guard let bytes = request.postBodyBytes, bytes.count > 0 else { return nil }
		let myZip = Zip()
		let fm = FileManager()
		// write incoming data to zip file that will be removed
		let zipTmp = fm.temporaryDirectory.appendingPathComponent(UUID().string).appendingPathExtension("zip")
		try Data(bytes: bytes).write(to: zipTmp)
		defer { try? fm.removeItem(at: zipTmp)}
		//create directory to expand zip into
		let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().string, isDirectory: true)
		try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let result = myZip.unzipFile(source: zipTmp.path, destination: tmpDir.path, overwrite: true)
		guard result == .ZipSuccess else {
			Log.warning(message: "error unzipping wspace files: \(result)", evenIdents: true)
			throw Errors.unzipError
		}
		return tmpDir
	}
}

