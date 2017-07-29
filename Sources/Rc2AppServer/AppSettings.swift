//
//  AppSettings.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import servermodel

public struct AppSettings {
	public let dataDirURL: URL
	public let computeHost: String
	public let dbHost: String
	public let dao: Rc2DAO
	private let encoder: JSONEncoder
	private let decoder: JSONDecoder
	
	init(dataDirURL: URL, computeHost: String, dbHost: String, dao: Rc2DAO) {
		self.dataDirURL = dataDirURL
		self.dao = dao
		self.computeHost = computeHost
		self.dbHost = dbHost
		encoder = JSONEncoder()
		encoder.dataEncodingStrategy = .base64
		encoder.dateEncodingStrategy = .secondsSince1970
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
		decoder = JSONDecoder()
		decoder.dataDecodingStrategy = .base64
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
	}
	
	func encode<T: Encodable>(_ object: T) throws -> Data {
		return try encoder.encode(object)
	}
	
	func decode<T: Decodable>(data: Data) throws -> T {
		return try decoder.decode(T.self, from: data)
	}
}
