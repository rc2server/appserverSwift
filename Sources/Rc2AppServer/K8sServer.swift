import Foundation
import MJLLogger
import BrightFutures
import PerfectCURL
import Freddy

enum K8sError: Error {
    case connectionFailed
    case invalidResponse
    case impossibleSituation
}

class K8sServer {
    private let token: String

    init() throws {
        // get the api credentials
        do {
            token = try String(contentsOfFile: "/var/run/secrets/kubernetes.io/serviceaccount/token")
        } catch {
            Log.info("failed to read k8s api credential")
            throw K8sError.connectionFailed
        }
    }

    /// Looks for a pod running a compute engine for the specified sessionId.
    ///
    /// - parameter sessionId: the sessionId to find an open compute session
    /// - returns: the hostname for the specified session, or nil if there is no such session running
    func hostName(wspaceId: Int) -> Future<String?, K8sError> {
        let rawUrl = "https://kubernetes.default.svc/api/v1/namespaces/default/pods?limit=1&labelSelector=app%3Dappserver"
        let request = CURLRequest(rawUrl, options: [.sslCAFilePath("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")])
        request.addHeader(.authorization, value: "Bearer \(token)")
        request.addHeader(.accept, value: "application/json")

        let promise = Promise<String?, K8sError>()
        Log.info("making api request")
        request.perform { confirmation in 
            Log.info("got api response")
            do {
                let response = try confirmation()
                let rdata = Data(response.bodyBytes)
                Log.info("got json from server: \(String(data: rdata, encoding: .utf8)!)")
                let json = try JSON(data: rdata)
                let ipAddr = try json.getString(at: "items", 0, "status", "podIP")
                Log.info("got ipAddr \(ipAddr)")
                promise.success(ipAddr)
            } catch {
                Log.error("curl got error: \(error)")
                promise.failure(K8sError.invalidResponse)
            }
        }
        Log.info("resumed api network task")
        return promise.future
    }
}
