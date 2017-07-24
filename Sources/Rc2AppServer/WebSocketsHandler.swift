//
//  PerfectHandlers.swift
//  WebSockets Server
//
//  Created by Kyle Jessup on 2016-01-06.
//  Copyright PerfectlySoft 2016. All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectWebSockets
import PerfectHTTP
import Dispatch
import PerfectCrypto
import servermodel

fileprivate let psecret = "32342fsa"

func makeRoutes() -> Routes {
	
	var routes = Routes()
    // Add a default route which lets us serve the static index.html file
	routes.add(method: .get, uri: "*", handler: { request, response in
		StaticFileHandler(documentRoot: request.documentRoot).handleRequest(request: request, response: response)
	})
	
	routes.add(method: .get, uri: "/test") { request, response in
		let jdata: [String: Any] = ["user": "login1", "id": 190]
		let encoder = JWTCreator(payload: jdata)!
		let str = try! encoder.sign(alg: .hs256, key: psecret)
		
		response.setBody(string: "worked\nauth=\(str)\n")
		response.addHeader(.contentEncoding, value: "plain/text")
		response.completed()
	}
	
	routes.add(method: .get, uri: "/authed") { request, response in
		let prefix = "Bearer "
		guard let rawHeader = request.header(.authorization) else { response.completed(status: .forbidden); return }
		print("raw header \(rawHeader)")
		let token = rawHeader.replacingOccurrences(of: prefix, with: "")
		print("token \(token)")
		guard let verifier = JWTVerifier(token) else { print("v failed"); response.completed(status: .forbidden); return }
//		var pgcon: PGConnection?
//		do {
//			try verifier.verify(algo: .hs256, key: psecret)
//			pgcon = try PGConnection(host: "localhost", user: "rc2", database: "rc2")
//		} catch {
//			print("error \(error)")
//			response.completed(status: .forbidden)
//			return
//		}
//		guard let username = (verifier.payload["user"] as? String) else { print("no user"); response.completed(status: .forbidden); return }
//		let dao = Rc2DAO(pgcon!)
//		do {
//			let user = try dao.getUser(login: username)
//			print("got user \(user!)")
//		} catch {
//			print("failed to get user \(error)")
//			response.completed(status: .forbidden)
//			return
//		}
//		guard let header = request.header(.authorization)?.trimmingCharacters(in: .whitespaces),
//			header.hasPrefix(prefix),
//			let verifier = JWTVerifier(header.replacingOccurrences(of: prefix, with: "")),
//			let _ = try? verifier.verify(algo: .hs256, key: psecret)
//			else { response.completed(status: .forbidden); return }
		print("got payload \(verifier.payload)")
		response.setBody(string: "ok\n")
		response.addHeader(.contentEncoding, value: "plain/text")
		response.completed()
		
	}
	
	// Add the endpoint for the WebSocket example system
	routes.add(method: .get, uri: "/echo", handler: {
        request, response in
        
        // To add a WebSocket service, set the handler to WebSocketHandler.
        // Provide your closure which will return your service handler.
        WebSocketHandler(handlerProducer: {
            (request: HTTPRequest, protocols: [String]) -> WebSocketSessionHandler? in
            
            // Check to make sure the client is requesting our "echo" service.
            guard protocols.contains("echo") else {
                return nil
            }
            
            // Return our service handler.
            return EchoHandler()
        }).handleRequest(request: request, response: response)
    })
	
	return routes
}

// A WebSocket service handler must impliment the `WebSocketSessionHandler` protocol.
// This protocol requires the function `handleSession(request: WebRequest, socket: WebSocket)`.
// This function will be called once the WebSocket connection has been established,
// at which point it is safe to begin reading and writing messages.
//
// The initial `WebRequest` object which instigated the session is provided for reference.
// Messages are transmitted through the provided `WebSocket` object.
// Call `WebSocket.sendStringMessage` or `WebSocket.sendBinaryMessage` to send data to the client.
// Call `WebSocket.readStringMessage` or `WebSocket.readBinaryMessage` to read data from the client.
// By default, reading will block indefinitely until a message arrives or a network error occurs.
// A read timeout can be set with `WebSocket.readTimeoutSeconds`.
// When the session is over call `WebSocket.close()`.
class EchoHandler: WebSocketSessionHandler {
	
	// The name of the super-protocol we implement.
	// This is optional, but it should match whatever the client-side WebSocket is initialized with.
	let socketProtocol: String? = "echo"
	
	// This function is called by the WebSocketHandler once the connection has been established.
	func handleSession(request: HTTPRequest, socket: WebSocket) {
		
		// Read a message from the client as a String.
		// Alternatively we could call `WebSocket.readBytesMessage` to get binary data from the client.
		socket.readStringMessage {
			// This callback is provided:
			//	the received data
			//	the message's op-code
			//	a boolean indicating if the message is complete (as opposed to fragmented)
			string, op, fin in
			
			// The data parameter might be nil here if either a timeout or a network error, such as the client disconnecting, occurred.
			// By default there is no timeout.
			guard let string = string else {
				// This block will be executed if, for example, the browser window is closed.
				socket.close()
				return
			}
			
			// Print some information to the console for informational purposes.
			print("Read msg: \(string) op: \(op) fin: \(fin)")
			
			// Echo the data we received back to the client.
			// Pass true for final. This will usually be the case, but WebSockets has the concept of fragmented messages.
			// For example, if one were streaming a large file such as a video, one would pass false for final.
			// This indicates to the receiver that there is more data to come in subsequent messages but that all the data is part of the same logical message.
			// In such a scenario one would pass true for final only on the last bit of the video.
			socket.sendStringMessage(string: string, final: true) {
				
				// This callback is called once the message has been sent.
				// Recurse to read and echo new message.
				self.handleSession(request: request, socket: socket)
			}
		}
	}
}


