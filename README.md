# Rc2AppServer

<p align="center">

<img alt="Swift 4.0" src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" style="max-width:100%;">

<img alt="Platforms OS X | Linux" src="https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat" style="max-width:100%;">

<img alt="License ISC" src="https://img.shields.io/badge/License-ISC-lightgrey.svg?style=flat" style="max-width:100%;">

</p>

Latest version of AppServer written in Swift, deployable on Linux.

## Build setup

To generate an xcodeproj, use `swift package generate-xcodeproj --xcconfig-overrides Mac.xcconfig`. This will override the deployment target which swift hardcodes at 10.10.

To compile from the command line on macOS, use `swift  build -Xswiftc "-target" -Xswiftc x86_64-apple-macosx10.12`
