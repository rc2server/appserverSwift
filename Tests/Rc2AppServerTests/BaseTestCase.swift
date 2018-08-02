import XCTest
#if os(Linux)
import Glibc
#endif

class BaseTestCase: XCTestCase {
    /// contains the path of the executable being run
    static let exePath: String? = {
    #if os(Linux)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
        buffer.initialize(repeating: 0, count: 1024)
        defer { buffer.deallocate() }
        let count = readlink("/proc/self/exe", &buffer.pointee, 1024)
        guard count > 0 else { return nil }
        return String(utf8String: buffer)
    #else 
        fatalError("not implemented for non-Linux")
    #endif
    }()

    /// assuming testing via SPM, will return the the URL of the project root appended with resource
    func urlFor(resource: String) -> URL {
        var url = URL(fileURLWithPath: BaseTestCase.exePath!)
        url.deleteLastPathComponent() // remove exe name
        url.deleteLastPathComponent() // move up to debug
        url.deleteLastPathComponent() // move up to build 
        url.deleteLastPathComponent() // move to project root
        url.appendPathComponent(resource)
        return url
    }
}
