import Foundation
import MJLLogger

enum K8sError: Error {
    case connectionFailed
}

class K8sServer {
    private let session: URLSession

    init() throws {
        // get the api credentials
        let token: String
        do {
            token = try String(contentsOfFile: "/var/run/secrets/kubernetes.io/serviceaccount/token")
        } catch {
            Log.info("failed to read k8s api credential")
            throw K8sError.connectionFailed
        }
        let config = URLSessionConfiguration.default
        if config.httpAdditionalHeaders == nil {
            config.httpAdditionalHeaders = [AnyHashable: Any]()
        }
        config.httpAdditionalHeaders?["Authorization"] = "Bearer \(token)"
        config.httpAdditionalHeaders?["Accept"] = "application/json"
        session = URLSession(configuration: config)
    }

    /// Looks for a pod running a compute engine for the specified sessionId.
    ///
    /// - parameter sessionId: the sessionId to find an open compute session
    /// - returns: the hostname for the specified session, or nil if there is no such session running
    func hostName(forSessionId: Int) -> String? {
        var components = URLComponents()
        components.host = "kubernetes.default.svc"
        components.path = "/api/v1/namespaces/default/pods"
        components.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "labelSelector", value: "app=appserver") // TODO: change to sessionId=xxxx
        ]
        guard let url = components.url else {
            Log.error("failed to create url for \(components)")
            return nil
        }
        var request = URLRequest(url: url)
        return nil
    }
}
