import Foundation
import MJLLogger
import BrightFutures
import PerfectCURL
import Freddy
import Stencil
import PathKit

enum K8sError: Error {
    case connectionFailed
    case invalidResponse
    case impossibleSituation
    case invalidConfiguration
}

// stencil templates are in config.k8sStencilPath

class K8sServer {
    private let token: String
    private let config: AppConfiguration
    private let stencilEnv: Environment

    init(config: AppConfiguration) throws {
        self.config = config
        // get the api credentials
        do {
            token = try String(contentsOfFile: "/var/run/secrets/kubernetes.io/serviceaccount/token")
            let fsLoader = FileSystemLoader(paths: [Path(config.k8sStencilPath)])
            stencilEnv = Environment(loader: fsLoader)
        } catch {
            Log.info("failed to read k8s api credential")
            throw K8sError.connectionFailed
        }
    }

    /// Fires off a job to kubernetes to start a compute instance for the specified workspace
    /// - Parameter wspaceId: the id of the workspace the compute engine will be using
    /// - Parameter sessionId: the unique, per-session id this compute instance is for
    /// - Returns: future is always true if no error happend
    /// FIXME: need to delay return value until the compute container is running and accepting connections
    func launchCompute(wspaceId: Int, sessionId: Int) -> Future<Bool, K8sError> {
        let promise = Promise<Bool, K8sError>()
        // for now only support basicComputeJob
        let jobString: String
        do {
            let context = ["wspaceId": String(wspaceId), "computeImage": config.computeImage, "sessionId": String(sessionId)]
            jobString = try stencilEnv.renderTemplate(name: "basicComputeJob.json", context: context)
            // for debugging purposes, log the job request
            try jobString.write(to: URL(fileURLWithPath: "/tmp/job-\(wspaceId)-\(sessionId).json"), atomically: true, encoding: .utf8)
        } catch {
            Log.error("failed to load compute job template: \(error)")
            promise.failure(.invalidConfiguration)
            return promise.future
        }
        let rawUrl = "https://kubernetes.default.svc/apis/batch/v1/namespaces/default/jobs"
        let request = CURLRequest(rawUrl, options: [.sslCAFilePath("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"), .postString(jobString), .httpMethod(.post)])
        request.addHeader(.authorization, value: "Bearer \(token)")
        request.addHeader(.accept, value: "application/json")
        request.addHeader(.contentType, value: "application/json")
        request.perform { confirmation in 
            do {
                let response = try confirmation()
                let statusCode = response.get(.responseCode)
                guard statusCode == 201 else {
                    Log.error("failed to create compute job: \(statusCode ?? 0)")
                    promise.failure(K8sError.invalidResponse)
                    return
                }
                // HACK: wait a bit to return so have time to start up
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(5000)) {
                    Log.info("delayed return after launch")
                    promise.success(true)
                }
            } catch {
                Log.error("error in launch job request: \(error)")
                promise.failure(.invalidResponse)
            }
        }
        return promise.future
    }

    /// represents the current status of a compute pod
    struct ComputePodStatus {
        enum Phase: String { case pending, running, succeeded, failed, unknown }
        let ipAddr: String?
        let phase: Phase

        var isRunning: Bool { if case .running = phase { return true }; return false }
    }


    /// Looks for a pod running a compute engine for the specified sessionId.
    ///
    /// - parameter sessionId: the sessionId to find an open compute session
    /// - returns: the hostname for the specified session, or nil if there is no such session running
    func computeStatus(sessionId: Int) -> Future<ComputePodStatus?, K8sError> {
        let rawUrl = "https://kubernetes.default.svc/api/v1/namespaces/default/pods?limit=1&labelSelector=sessionId%3D\(sessionId)"
        let request = CURLRequest(rawUrl, options: [.sslCAFilePath("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")])
        request.addHeader(.authorization, value: "Bearer \(token)")
        request.addHeader(.accept, value: "application/json")

        let promise = Promise<ComputePodStatus?, K8sError>()
        request.perform { confirmation in 
            let rdata: Data
            do {
                let response = try confirmation()
                rdata = Data(response.bodyBytes)
                // for debugging puroposes
                try rdata.write(to: URL(fileURLWithPath: "/tmp/lastStatus.json"))
            } catch {
                Log.error("curl got an error: \(error)")
                promise.failure(K8sError.invalidResponse)
                return
            }
            do {
                let json = try JSON(data: rdata)
                let ipAddr = try json.decode(at: "items", 0, "status", "podIP", alongPath: .missingKeyBecomesNil, type: String.self)
                let phase = try json.getString(at: "items", 0, "status", "phase").lowercased()
                Log.info("got ipAddr \(ipAddr ?? "-"), phase=\(phase)")
                let phaseEnum: ComputePodStatus.Phase
                if let parsedPhase = ComputePodStatus.Phase(rawValue: phase) {
                    phaseEnum = parsedPhase
                } else {
                    phaseEnum = .unknown
                }
                let status = ComputePodStatus(ipAddr: ipAddr, phase: phaseEnum)
                promise.success(status)
            } catch JSON.Error.indexOutOfBounds(_) {
                // no pod found
                Log.info("no pod found for \(sessionId)")
                promise.success(nil)
            } catch {
                Log.warn("failed to find workspace pod: \(error)")
                promise.success(nil)
            }
        }
        return promise.future
    }
}
