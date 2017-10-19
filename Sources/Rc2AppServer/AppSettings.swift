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
	public let config: AppConfiguration
	/// the encoder used, implementation detail.
	private let encoder: JSONEncoder
	/// the decoder used, implementation detail.
	private let decoder: JSONDecoder
	
	public static func createJSONEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .secondsSince1970
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
		return encoder
	}

	public static func createJSONDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
		return decoder
	}
	/// Initializes from parameters and `config.json`
	/// 
	/// - Parameter dataDirURL: URL containing resources used by the application.
	/// - Parameter configData: JSON data for configuration. If nil, will read it from dataDirURL.
	/// - Parameter dao: The Data Access Object used to retrieve model objects from the database.
	init(dataDirURL: URL, configData: Data? = nil, dao: Rc2DAO) {
		self.dataDirURL = dataDirURL
		self.dao = dao

		self.encoder = AppSettings.createJSONEncoder()
		self.decoder = AppSettings.createJSONDecoder()

		do {
			let configUrl = dataDirURL.appendingPathComponent("config.json")
			let data = configData != nil ? configData! : try Data(contentsOf: configUrl)
			config = try decoder.decode(AppConfiguration.self, from: data)
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
	
}

/// Basic information used throughout the application. Meant to be read from config file.
public struct AppConfiguration: Decodable {
	/// The database host name to connect to. Defaults to "dbserver".
	public let dbHost: String
	/// The database port to connect to. Defaults to 5432.
	public let dbUser: String
	/// The name of the user to connect as. Defaults to "rc2".
	public let dbName: String
	/// The host name of the compute engine. Defaults to "compute".
	public let computeHost: String
	/// The port of the compute engine. Defaults to 7714.
	public let computePort: UInt16
	/// Seconds to wait for a connection to the compute engine to open. Defaults to 4. -1 means no timeout.
	public let computeTimeout: Double
	/// The db host name to send to the compute server (which because of dns can be different)
	public let computeDbHost: String
	/// The largest amount of file data to return over the websocket. Anything higher should be fetched via REST. In KB
	public let maximumWebSocketFileSizeKB: Int
	/// Path to store log files
	public let logfilePath: String
	
	enum CodingKeys: String, CodingKey {
		case dbHost
		case dbUser
		case dbName
		case computeHost
		case computePort
		case computeTimeout
		case computeDbHost
		case maximumWebSocketFileSizeKB
		case logFilePath
	}
	
	/// Initializes from serialization.
	///
	/// - Parameter from: The decoder to deserialize from.
	public init(from cdecoder: Decoder) throws {
		let container = try cdecoder.container(keyedBy: CodingKeys.self)
		logfilePath = try container.decodeIfPresent(String.self, forKey: .logFilePath) ?? "/tmp/appserver.log"
		dbHost = try container.decodeIfPresent(String.self, forKey: .dbHost) ?? "dbserver"
		dbUser = try container.decodeIfPresent(String.self, forKey: .dbUser) ?? "rc2"
		dbName = try container.decodeIfPresent(String.self, forKey: .dbName) ?? "rc2"
		computeHost = try container.decodeIfPresent(String.self, forKey: .computeHost) ?? "compute"
		computePort = try container.decodeIfPresent(UInt16.self, forKey: .computePort) ?? 7714
		computeTimeout = try container.decodeIfPresent(Double.self, forKey: .computeTimeout) ?? 4.0
		let cdb = try container.decodeIfPresent(String.self, forKey: .computeDbHost)
		computeDbHost = cdb == nil ? dbHost : cdb!
		// default to 600 KB. Some kind of issues with sending messages larger than UInt16.max
		if let desiredSize = try container.decodeIfPresent(Int.self, forKey: .maximumWebSocketFileSizeKB),
			desiredSize <= 600, desiredSize > 0
		{
			maximumWebSocketFileSizeKB = desiredSize
		} else {
			maximumWebSocketFileSizeKB = 600
		}
	}
}
