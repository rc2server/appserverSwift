import Foundation

public class Item: CustomStringConvertible  {
	public let name: String
	public let weight: Double

	public init(name: String, weight: Double = 1.0) {
		self.name = name
		self.weight = weight
	}
	public var description: String {
		return "\(name):\(weight)"
	}
}

