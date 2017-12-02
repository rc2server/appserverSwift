//
//  Variable+JSON.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Rc2Model
import Freddy
import MJLLogger

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
					vtype = .dataFrame(try parseDataFrame(json: json))
				case "list":
					vtype = .list([]) // FIXME: need to parse
				default:
					//make sure it is an object we can handle
					guard try json.getBool(at: "generic", or: false) else { throw VariableError("unknown parsing error \(className)") }
					var attrs = [String: Variable]()
					let rawValues = try json.getDictionary(at: "value")
					for aName in try json.decodedArray(at: "names", type: String.self) {
						if let attrJson = rawValues[aName], let value = try? makeFromLegacy(json: attrJson) {
							attrs[aName] = value
						}
					}
					vtype = .generic(attrs)
				}
			}
			return Variable(name: vname, length: vlen, type: vtype, className: className, summary: summary)
		} catch let verror as VariableError {
			throw verror
		} catch {
			Log.warn("error parsing legacy variable: \(error)")
			throw VariableError("error parsing legacy variable", error: error)
		}
	}
	
	static func parseDataFrame(json: JSON) throws -> DataFrameData {
		do {
			let numCols = try json.getInt(at: "ncol")
			let numRows = try json.getInt(at: "nrow")
			let rowNames: [String]? = try json.decodedArray(at: "row.names", alongPath: .missingKeyBecomesNil)
			let rawColumns = try json.getArray(at: "columns")
			let columns = try rawColumns.map { (colJson: JSON) -> DataFrameData.Column in
				let colName = try colJson.getString(at: "name")
				return DataFrameData.Column(name: colName, value: try makePrimitive(json: colJson, valueKey: "values"))
			}
			guard columns.count == numCols
				else { throw VariableError("data does not match num cols/rows") }
			return DataFrameData(columns: columns, rowCount: numRows, rowNames: rowNames)
		} catch let verror as VariableError {
			throw verror
		} catch {
			throw VariableError("error parsing data frame", error: error)
		}
	}
	
	static func parseMatrix(json: JSON) throws -> MatrixData {
		do {
			let numCols = try json.getInt(at: "ncol")
			let numRows = try json.getInt(at: "nrow")
			let rowNames: [String]? = try? json.decodedArray(at: "dimnames", 0)
			let colNames: [String]? = try? json.decodedArray(at: "dimnames", 1)
			guard rowNames == nil || rowNames!.count == numRows
				else { throw VariableError("row names do not match length") }
			guard colNames == nil || colNames!.count == numCols
				else { throw VariableError("col names do not match length") }
			let values = try makePrimitive(json: json)
			return MatrixData(value: values, rowCount: numRows, colCount: numCols, colNames: colNames, rowNames: rowNames)
		} catch let verror as VariableError {
			throw verror
		} catch {
			throw VariableError("error parsing matrix data", error: error)
		}
	}
	
	// parses array of doubles, "Inf", "-Inf", and "NaN" into [Double]
	static func parseDoubles(json: [JSON]) throws -> [Double?] {
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
			case .null:
				return nil
			default:
				throw VariableError("invalid value type in double array")
			}
		}
	}
	
	// returns a PrimitiveValue based on the contents of json
	static func makePrimitive(json: JSON, valueKey: String = "value") throws -> PrimitiveValue {
		guard let ptype = try? json.getString(at: "type")
			else { throw VariableError("invalid primitive type") }
		guard let rawValues = try json.getArray(at: valueKey, alongPath: .missingKeyBecomesNil)
			else { throw VariableError("invalid value") }
		var pvalue: PrimitiveValue
		switch ptype {
		case "n":
			pvalue = .null
		case "b":
			let bval: [Bool?] = try rawValues.map { (aVal: JSON) -> Bool? in
				if case .null = aVal { return nil }
				if case let .bool(aBool) = aVal { return aBool }
				throw VariableError("invalid bool variable \(aVal)")
			}
			pvalue = .boolean(bval)
		case "i":
			let ival: [Int?] = try rawValues.map { (aVal: JSON) -> Int? in
				if case .null = aVal { return nil }
				if case let .int(anInt) = aVal { return anInt }
				throw VariableError("invalid int variable \(aVal)")
			}
			pvalue = .integer(ival)
		case "d":
			pvalue = .double(try parseDoubles(json: json.getArray(at: valueKey, alongPath: .nullBecomesNil)!))
		case "s":
			let sval: [String?] = try rawValues.map { (aVal: JSON) -> String? in
				if case .null = aVal { return nil }
				if case let .string(aStr) = aVal { return aStr }
				throw VariableError("invalid string variable \(aVal)")
			}
			pvalue = .string(sval)
		case "c":
			let cval: [String?] = try rawValues.map { (aVal: JSON) -> String? in
				if case .null = aVal { return nil }
				if case let .string(aStr) = aVal { return aStr }
				throw VariableError("invalid complex variable \(aVal)")
			}
			pvalue = .complex(cval)
		case "r":
			pvalue = .raw
		default:
			throw VariableError("unknown primitive type: \(ptype)")
		}
		return  pvalue
	}
}

