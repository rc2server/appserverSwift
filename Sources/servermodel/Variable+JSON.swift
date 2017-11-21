//
//  Variable+JSON.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Rc2Model
import Freddy
import LoggerAPI

struct VariableError: Error {
	let reason: String
	let nestedError: Error?
	init(_ reason: String, error: Error? = nil) {
		self.reason = reason
		self.nestedError = error
	}
}

extension Variable {
	static let rDateFormatter: ISO8601DateFormatter = { var f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate, .withDashSeparatorInDate]; return f}()
	
	/// Parses a legacy compute json dictionary into a Variable
	public static func makeFromLegacy(json: JSON) throws -> Variable {
		do {
			let vname = try json.getString(at: "name")
			let className = try json.getString(at: "class")
			let summary = try json.getString(at: "summary", or: "")
			let vlen = try json.getInt(at: "length", or: 1)
			var vtype: VariableType
			if try json.getBool(at: "primitive", or: false) {
				vtype = .primitive(try makePrimitive(json: json))
			} else if try json.getBool(at: "s4", or: false) {
				vtype = .s4Object
			} else {
				switch className {
				case "Date":
					do {
						guard let vdate = rDateFormatter.date(from: try json.getString(at: "value"))
							else { throw VariableError("invalid date value") }
						vtype = .date(vdate)
					} catch {
						throw VariableError("invalid date value", error: error)
					}
				case "POSIXct", "POSIXlt":
					do {
						vtype = .dateTime(Date(timeIntervalSince1970: try json.getDouble(at: "value")))
					} catch {
						throw VariableError("invalid date value", error: error)
					}
				case "function":
					do {
						vtype = .function(try json.getString(at: "body"))
					} catch {
						throw VariableError("function w/o body", error: error)
					}
				case "factor", "ordered factor":
					do {
						vtype = .factor(values: try json.decodedArray(at: "value"), levelNames: try json.decodedArray(at: "levels", or: []))
					} catch {
						throw VariableError("factor missing values", error: error)
					}
				case "matrix":
					vtype = .matrix(try parseMatrix(json: json))
				case "environment":
					vtype = .environment // FIXME: need to parse key/value pairs sent as value
				case "data.frame":
					vtype = .dataFrame(try parseDataFrame(json: json))// FIXME: need to implement
				case "list":
					vtype = .list([]) // FIXME: need to parse
				default:
					// our should we just set type to .unknown?
					throw VariableError("unknown parsing error")
				}
			}
			return Variable(name: vname, length: vlen, type: vtype, className: className, summary: summary)
		} catch let verror as VariableError {
			throw verror
		} catch {
			Log.warning("error parsing legacy variable: \(error)")
			throw VariableError("error parsing legacy variable", error: error)
		}
	}
	
	static func parseDataFrame(json: JSON) throws -> DataFrameData {
		return DataFrameData(value: [], colCount: 1, rowCount: 1, colNames: ["foo"], rowNames: nil)
	}
	
	static func parseMatrix(json: JSON) throws -> MatrixData {
		do {
			let typeCode = try json.getString(at: "type")
			let numCols = try json.getInt(at: "ncol")
			let numRows = try json.getInt(at: "nrow")
			let rowNames: [String]? = try? json.decodedArray(at: "dimnames", 0)
			let colNames: [String]? = try? json.decodedArray(at: "dimnames", 1)
			guard rowNames == nil || rowNames!.count == numRows
				else { throw VariableError("row names do not match length") }
			guard colNames == nil || colNames!.count == numCols
				else { throw VariableError("col names do not match length") }
			let values = try parseMatrixData(type: typeCode, json: json)
			return MatrixData(value: values, rowCount: numRows, colCount: numCols, colNames: colNames, rowNames: rowNames)
		} catch let verror as VariableError {
			throw verror
		} catch {
			throw VariableError("error parsing matrix data", error: error)
		}
	}
	
	static func parseMatrixData(type: String, json: JSON) throws -> PrimitiveValue {
		switch type {
		case "b":
			return .boolean(try json.decodedArray(at: "value"))
		case "d":
			return .double(try parseDoubles(json: json.getArray(at: "value")))
		case "i":
			return .integer(try json.decodedArray(at: "value"))
		case "s":
			return .string(try json.decodedArray(at: "value"))
		case "c":
			return .complex(try json.decodedArray(at: "value"))
		default:
			break
		}
		throw VariableError("unsupported data type for matrix values")
	}
	
	// parses array of doubles, "Inf", "-Inf", and "NaN" into [Double]
	static func parseDoubles(json: [JSON]) throws -> [Double] {
		return try json.map { (aVal) in
			switch aVal {
			case .double(let dval):
				return dval
			case .int(let ival):
				return Double(ival)
			case .string(let sval):
				switch sval {
				case "Inf": return Double.infinity
				case "-Inf": return -Double.infinity
				case "NaN": return Double.nan
				default: throw VariableError("invalid string as double value \(aVal)")
				}
			default:
				throw VariableError("invalid value type in double array")
			}
		}
	}
	
	// returns a PrimitiveValue based on the contents of dict
	static func makePrimitive(json: JSON) throws -> PrimitiveValue {
		guard let ptype = try? json.getString(at: "type")
			else { throw VariableError("invalid primitive type") }
		var pvalue: PrimitiveValue
		switch ptype {
		case "n":
			pvalue = .null
		case "b":
			guard let bval: [Bool] = try? json.decodedArray(at: "value")
				else { throw VariableError("bool primitive with invalid value") }
			pvalue = .boolean(bval)
		case "i":
			guard let ival: [Int] = try? json.decodedArray(at: "value")
				else { throw VariableError("int primitive with invalid value") }
			pvalue = .integer(ival)
		case "d":
			pvalue = .double(try parseDoubles(json: json.getArray(at: "value")))
		case "s": // FIXME: does this properly decode arrays of optional values?
			guard let sval: [String?] = try? json.decodedArray(at: "value")
				else { throw VariableError("string primitive with invalid value") }
			pvalue = .string(sval)
		case "c":
			guard let cval: [String?] = try? json.decodedArray(at: "value")
				else { throw VariableError("complex primitive with invalid value") }
			pvalue = .complex(cval)
		case "r":
			pvalue = .raw
		default:
			throw VariableError("unknown primitive type: \(ptype)")
		}
		return  pvalue
	}

/*	// returns a PrimitiveValue based on the contents of dict
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
		case "s": // FIXME: can be nullptrs
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
	} */
}

