//
//  AppSettings.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import servermodel

public struct AppSettings {
	/// URL for a directory that contains resources used by the application.
	public let dataDirURL: URL
	/// The data access object for retrieving objects from the database.
	public let dao: Rc2DAO
	/// Constants read from "config.json" in `dataDirURL`.
	public let config: Configuration
	/// the encoder used, implementation detail.
	private let encoder: JSONEncoder
	/// the decoder used, implementation detail.
	private let decoder: JSONDecoder
	
	/// Initializes from parameters and `config.json`
	/// 
	/// - Parameter dataDirURL: URL containing resources used by the application.
	/// - Parameter dao: The Data Access Object used to retrieve model objects from the database.
	init(dataDirURL: URL, dao: Rc2DAO) {
		self.dataDirURL = dataDirURL
		self.dao = dao

		encoder = JSONEncoder()
		encoder.dataEncodingStrategy = .base64
		encoder.dateEncodingStrategy = .secondsSince1970
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
		decoder = JSONDecoder()
		decoder.dataDecodingStrategy = .base64
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")

		do {
			let configUrl = dataDirURL.appendingPathComponent("config.json")
			let configData = try Data(contentsOf: configUrl)
			config = try decoder.decode(Configuration.self, from: configData)
		} catch {
			fatalError("failed to load config file \(error)")
		}
	}
	
	/// Encodes an object for transmission to the client
	///
	/// - Parameter object: The object to encode.
	/// - Returns: the data containing the encoded version of `object`.
	/// - Throws: any error raised by the encoder.
	func encode<T: Encodable>(_ object: T) throws -> Data {
		return try encoder.encode(object)
	}
	
	/// Decodes an object from the client.
	///
	/// - Parameter data: The data received from the client.
	/// - Returns: the decoded object.
	/// - Throws: any error raised by the decoder.
	func decode<T: Decodable>(data: Data) throws -> T {
		return try decoder.decode(T.self, from: data)
	}
	
	/// Basic information used throughout the application. Meant to be read from config file.
	public struct Configuration: Decodable {
		/// The database host name to connect to. Defaults to "dbserver".
		public let dbHost: String
		/// The database port to connect to. Defaults to 5432.
		public let dbPort: UInt16
		/// The name of the database to connect to. Defaults to "rc2".
		public let dbName: String
		/// The host name of the compute engine. Defaults to "compute".
		public let computeHost: String
		/// The port of the compute engine. Defaults to 7714.
		public let computePort: UInt16
		/// Seconds to wait for a connection to the compute engine to open. Defaults to 4. -1 means no timeout.
		public let computeTimeout: Int
		
		enum CodingKeys: String, CodingKey {
			case dbHost
			case dbPort
			case dbName
			case computeHost
			case computePort
			case computeTimeout
		}
		
		/// Initializes from serialization.
		///
		/// - Parameter from: The decoder to deserialize from.
		public init(from cdecoder: Decoder) throws {
			let container = try cdecoder.container(keyedBy: CodingKeys.self)
			dbHost = try container.decodeIfPresent(String.self, forKey: .dbHost) ?? "dbserver"
			dbPort = try container.decodeIfPresent(UInt16.self, forKey: .dbPort) ?? 5432
			dbName = try container.decodeIfPresent(String.self, forKey: .dbName) ?? "rc2"
			computeHost = try container.decodeIfPresent(String.self, forKey: .computeHost) ?? "compute"
			computePort = try container.decodeIfPresent(UInt16.self, forKey: .computePort) ?? 7714
			computeTimeout = try container.decodeIfPresent(Int.self, forKey: .computeTimeout) ?? 4
		}
	}
}
