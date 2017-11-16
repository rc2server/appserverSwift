//
//  Variable+JSON.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Rc2Model

struct VariableError: Error {
	let reason: String
	let dictionary: [String: Any]?
	init(_ reason: String, _ dict: [String: Any]?) {
		self.reason = reason
		self.dictionary = dict
	}
}

extension Variable {
	static let rDateFormatter: ISO8601DateFormatter = { var f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate, .withDashSeparatorInDate]; return f}()
	
	/// Parses a legacy compute json dictionary into a Variable
	public static func makeFromLegacy(dict: [String: Any]) throws -> Variable {
		guard let vname = dict["name"] as? String else { throw VariableError("unnamed variable", dict) }
		guard let cname = dict["class"] as? String else { throw VariableError("no class name", dict) }
		let summary = (dict["summary"] as? String) ?? ""
		let vlen = (dict["length"] as? Int) ?? 1
		var vtype: VariableType
		if let primitive = dict["primitive"] as? Bool, primitive {
			vtype = .primitive(try makePrimitive(dict: dict))
		} else if let isS4 = dict["s4"] as? Bool, isS4 {
			vtype = .s4Object
		} else {
			switch cname {
			case "Date":
				guard let dstr = dict["value"] as? String, let dval = rDateFormatter.date(from: dstr) else { throw VariableError("invalid date value", dict)}
				vtype = .date(dval)
			case "POSIXct", "POSIXlt":
				guard let tval = dict["value"] as? Double else { throw VariableError("invalid date value", dict)}
				vtype = .dateTime(Date(timeIntervalSince1970: tval))
			case "function":
				guard let fbody = dict["body"] as? String else { throw VariableError("function w/o body", dict) }
				vtype = .function(fbody)
			case "factor", "ordered factor":
				guard let values = dict["value"] as? [Int] else { throw VariableError("factor missing values", dict) }
				vtype = .factor(values: values, levelNames: dict["levels"] as? [String])
			case "matrix":
				vtype = .matrix(try parseMatrix(dict: dict))
			case "environment":
				vtype = .environment // FIXME: need to parse key/value pairs sent as value
			case "data.frame":
				vtype = .dataFrame // FIXME: need to implement
			case "list":
				vtype = .list([]) // FIXME: need to parse
			default:
				// our should we just set type to .unknown?
				throw VariableError("unknown parsing error", dict)
			}
		}
		return Variable(name: vname, length: vlen, type: vtype, className: cname, summary: summary)
	}
	
	static func parseMatrix(dict: [String: Any]) throws -> MatrixData {
		guard let valueLen = dict["length"] as? Int,
			let typeCode = dict["type"] as? String,
			let numCols = dict["ncol"] as? Int,
			let numRows = dict["nrow"] as? Int,
			let dimnames = dict["dimnames"] as? [[String]]
			else { throw VariableError("failed to parse required matrix fields", dict) }
		let rowNames = dimnames[0]
		let colNames = dimnames[1]
		guard colNames.count == numCols, rowNames.count == numRows
			else { throw VariableError("dimnames do not match lengths", dict) }
		guard let rawValues = dict["value"] as? [Any],
			rawValues.count == valueLen
			else { throw VariableError("failed to parse values", dict) }
		let values = try parseMatrixData(type: typeCode, rawData: rawValues, dict: dict)
		return MatrixData(value: values, rowCount: numRows, colCount: numCols, colNames: colNames, rowNames: rowNames)
	}
	
	static func parseMatrixData(type: String, rawData: [Any], dict: [String: Any]) throws -> PrimitiveValue {
		switch type {
		case "b":
			if let vals = rawData as? [Bool] { return .boolean(vals) }
		case "d":
			return .double(try parseDoubles(input: rawData))
		case "i":
			if let vals = rawData as? [Int] { return .integer(vals) }
		case "s":
			if let vals = rawData as? [String] { return .string(vals) }
		case "c":
			if let vals = rawData as? [String] { return .complex(vals) }
		default:
			break
		}
		throw VariableError("unsupported data type for matrix values", dict)
	}
	
	// parses array of doubles, "Inf", "-Inf", and "NaN" into [Double]
	static func parseDoubles(input: [Any]) throws -> [Double] {
		return try input.map { (aVal) in
			if let dval = aVal as? Double { return dval }
			guard let sval = aVal as? String else { throw VariableError("invalid double value in \(input)", nil) }
			switch sval {
			case "Inf": return Double.infinity
			case "-Inf": return -Double.infinity
			case "NaN": return Double.nan
			default: throw VariableError("invalid string as double value \(aVal)", nil)
			}
		}
	}
	
	// returns a PrimitiveValue based on the contents of dict
	static func makePrimitive(dict: [String: Any]) throws -> PrimitiveValue {
		guard let ptype = dict["type"] as? String
			else { throw VariableError("invalid primitive type", dict) }
		var pvalue: PrimitiveValue
		switch ptype {
		case "n":
			pvalue = .null
		case "b":
			guard let bval = dict["value"] as? [Bool] else { throw VariableError("bool primitive with invalid value", dict) }
			pvalue = .boolean(bval)
		case "i":
			guard let ival = dict["value"] as? [Int] else { throw VariableError("int primitive with invalid value", dict) }
			pvalue = .integer(ival)
		case "d":
			if let dval = dict["value"] as? [Double] {
				pvalue = .double(try parseDoubles(input: dval))
			} else if let ival = dict["value"] as? [Int] {
				pvalue = .double(ival.map { Double($0) })
			} else {
				throw VariableError("double primitive with invalid value", dict)
			}
		case "s":
			guard let sval = dict["value"] as? [String] else { throw VariableError("string primitive with invalid value", dict) }
			pvalue = .string(sval)
		case "c":
			guard let cval = dict["value"] as? [String] else { throw VariableError("complex primitive with invalid value", dict) }
			pvalue = .complex(cval)
		case "r":
			pvalue = .raw
		default:
			throw VariableError("unknown primitive type: \(ptype)", dict)
		}
		return  pvalue
	}
}

