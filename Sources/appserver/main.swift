import PerfectCrypto
import Rc2AppServer
#if os(Linux)
	import Glibc
#else
	import Darwin
#endif

PerfectCrypto.isInitialized = true

let server = AppServer()

signal(SIGINT) { _ in
	print("got SIGINT. Terminating.")
	server.stop()
}

server.start()
