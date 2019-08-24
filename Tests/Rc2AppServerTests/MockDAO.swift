//
//  MockDAO.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
@testable import servermodel
import Rc2Model
import PostgreSQL

class MockDAO: Rc2DAO {
	var user: User = User(id: 101, version: 1, login: "test", email: "test@rc2.io")
	var emptyProject = Project(id: 101, version: 1, userId: 101, name: "proj1")
	var wspace101 = Workspace(id: 101, version: 1, name: "awspace", userId: 101, projectId: 101, uniqueId: "w2space1", lastAccess: Date(), dateCreated: Date())
	var wspace102 = Workspace(id: 102, version: 1, name: "bwspace", userId: 101, projectId: 101, uniqueId: "w2space2", lastAccess: Date(), dateCreated: Date())
	var file101 = File(id: 101, wspaceId: 101, name: "foo.pdf", version: 1, dateCreated: Date(), lastModified: Date(), fileSize: 1899)
	var image201 = SessionImage(id: 201, sessionId: 200, batchId: 2, name: "plot1.png", title: nil, dateCreated: Date(), imageData: Data(repeatElement(0x45, count: 890)))
	var image202 = SessionImage(id: 202, sessionId: 200, batchId: 2, name: "plot2.png", title: nil, dateCreated: Date(), imageData: Data(repeatElement(0x45, count: 211)))
	
	override public func getProjects(ownedBy: User, connection: PostgreSQL.Connection? = nil) throws -> [Project] {
		return [emptyProject]
	}
	
	override func getUser(id: Int, connection: Connection?) throws -> User? {
		return user
	}
	
	override func getUserInfo(user: User) throws -> BulkUserInfo {
		return BulkUserInfo(user: user, projects: [emptyProject], workspaces: [101: [wspace101]], files: [101: [file101]])
	}
	
	override func getFile(id: Int, userId: Int, connection: Connection?) throws -> File? {
		guard id == file101.id else { return nil }
		return file101
	}
	
	override func getFileData(fileId: Int, connection: Connection?) throws -> Data {
		guard fileId == file101.id else { throw ModelError.notFound }
		return Data(repeatElement(0x45, count: file101.fileSize))
	}
	
	override func getImages(imageIds: [Int]?) throws -> [SessionImage] {
		return [ image201, image202 ]
	}
}

