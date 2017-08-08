//
//  SemanticVersion.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation

extension String {
	/// retarded change in Swift 4 doesn't allow creating an optional string from an optional substring
	init?(_ substr: Substring?) {
		guard let ss = substr else { return nil }
		self.init(ss)
	}
}

struct SemanticVersion {
	let major: Int
	let minor: Int
	let patch: Int
	let prerelease: String?
	let build: String?
	
	enum Errors: Error {
		case invalidString
	}
	
	private static func substring(string: String, nsRange: NSRange) -> Substring? {
		guard nsRange.length > 0 else { return nil }
		guard let srange = Range(nsRange, in: string) else { return nil }
		return string[srange]
	}
	
	init(major: Int, minor: Int, patch: Int, prerelease: String?, build: String?) {
		self.major = major
		self.minor = minor
		self.patch = patch
		self.prerelease = prerelease
		self.build = build
	}
	
	init?(_ string: String) throws {
		//pattern matches standard from semver.org
		let range = NSRange(string.startIndex..<string.endIndex, in: string)
		let regex = try NSRegularExpression(pattern: "^((?:[1-9]?)(?:[0-9]*))\\.((?:[1-9]?)(?:[0-9]*))\\.(?:([1-9]?)(?:[0-9]*))(?:-([0-9A-Za-z.-]+))?(?:\\+([0-9A-Za-z.-]+))?$", options: [])
		guard
			let match = regex.firstMatch(in: string, options: [], range: range),
			let majorNSRange = Optional.some(match.range(at: 1)), majorNSRange.length > 0,
			let majorRange = Range(majorNSRange, in: string),
			let major = Int(string[majorRange]),
			let minorNSRange = Optional.some(match.range(at: 2)), minorNSRange.length > 0,
			let minorRange = Range(minorNSRange, in: string),
			let minor = Int(string[minorRange]),
			let patchNSRange = Optional.some(match.range(at: 3)), patchNSRange.length > 0,
			let patchRange = Range(patchNSRange, in: string),
			let patch = Int(string[patchRange])
			else {
				throw Errors.invalidString
		}
		var build: Substring? = nil
		var prerelease: Substring? = nil
		if match.numberOfRanges > 4 {
			//there is both build and prerelease
			prerelease = SemanticVersion.substring(string: string, nsRange: match.range(at: 4))
			build = SemanticVersion.substring(string: string, nsRange: match.range(at: 5))
		} else if match.numberOfRanges > 3 {
			guard let extraStr = SemanticVersion.substring(string: string, nsRange: match.range(at: 4)) else { throw Errors.invalidString }
			switch extraStr[extraStr.startIndex] {
			case "-":
				let start = extraStr.index(after: extraStr.startIndex)
				prerelease = extraStr[start...]
			case "+":
				let start = extraStr.index(after: extraStr.startIndex)
				build = extraStr[start...]
			default:
				throw Errors.invalidString
			}
		}
		self = SemanticVersion(major: major, minor: minor, patch: patch, prerelease: String(prerelease), build: String(build))
	}
}
