//
//  AppSettings.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import servermodel

public struct AppSettings {
	public let dataDirURL: URL
	public let dao: Rc2DAO
	public let encoder: JSONEncoder
	public let decoder: JSONDecoder
	
	init(dataDirURL: URL, dao: Rc2DAO) {
		self.dataDirURL = dataDirURL
		self.dao = dao
		encoder = JSONEncoder()
		encoder.dataEncodingStrategy = .base64Encode
		encoder.dateEncodingStrategy = .secondsSince1970
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
		decoder = JSONDecoder()
		decoder.dataDecodingStrategy = .base64Decode
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
	}
}
