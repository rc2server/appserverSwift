//
//  AppSettings.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import servermodel
import MJLLogger

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
		Log.info("settings inited with: \(dataDirURL.absoluteString)")
		self.dataDirURL = dataDirURL
		self.dao = dao

		self.encoder = AppSettings.createJSONEncoder()
		self.decoder = AppSettings.createJSONDecoder()

		var configUrl: URL!
		do {
			configUrl = dataDirURL.appendingPathComponent("config.json")
			let data = configData != nil ? configData! : try Data(contentsOf: configUrl)
			config = try decoder.decode(AppConfiguration.self, from: data)
		} catch {
			fatalError("failed to load config file \(configUrl.absoluteString) \(error)")
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
	/// The password to connect to the database. Defaults to "rc2".
	public let dbPassword: String
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
	/// The initial log level. Defaults to info
	public let initialLogLevel: LogLevel
	/// Path to store log files
	public let logfilePath: String
	/// URL prefix to ignore when parsing urls (e.g. "/v1" or "/dev")
	public let urlPrefixToIgnore: String
	/// Should the compute engine be launched via Kubernetes, or connected to via computeHost/computePort settings
	public let computeViaK8s: Bool
	/// Path where stencil templates for k8s are found. Defaults to "/rc2/k8s-templates"
	public let k8sStencilPath: String
	/// The Docker image to use for the compute pods
	public let computeImage: String
	/// How long a session be allowed to stay im memory without any users before it is reaped. in seconds. Defaults to 300.
	public let sessionReapDelay: Int
	
	enum CodingKeys: String, CodingKey {
		case dbHost
		case dbUser
		case dbName
		case dbPassword
		case computeHost
		case computePort
		case computeTimeout
		case computeDbHost
		case maximumWebSocketFileSizeKB
		case logFilePath
		case initialLogLevel
		case urlPrefixToIgnore
		case computeViaK8s
		case k8sStencilPath
		case computeImage
		case sessionReapDelay
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
		dbPassword = try container.decodeIfPresent(String.self, forKey: .dbPassword) ?? "rc2"
		computeHost = try container.decodeIfPresent(String.self, forKey: .computeHost) ?? "compute"
		computePort = try container.decodeIfPresent(UInt16.self, forKey: .computePort) ?? 7714
		computeTimeout = try container.decodeIfPresent(Double.self, forKey: .computeTimeout) ?? 4.0
		urlPrefixToIgnore = try container.decodeIfPresent(String.self, forKey: .urlPrefixToIgnore) ?? ""
		computeViaK8s = try container.decodeIfPresent(Bool.self, forKey: .computeViaK8s) ?? false
		k8sStencilPath = try container.decodeIfPresent(String.self, forKey: .k8sStencilPath) ?? "/rc2/k8s-templates"
		computeImage = try container.decodeIfPresent(String.self, forKey: .computeImage) ?? "docker.rc2.io/compute:latest"
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
		if let desiredReapTime = try container.decodeIfPresent(Int.self, forKey: .sessionReapDelay), desiredReapTime >= 0, desiredReapTime < 3600
		{
			sessionReapDelay = desiredReapTime
		} else {
			sessionReapDelay = 300
		}
		if let levelStr = try container.decodeIfPresent(Int.self, forKey: .initialLogLevel), let level = LogLevel(rawValue: levelStr) {
			initialLogLevel = level
		} else {
			initialLogLevel = .info
		}
	}
}
