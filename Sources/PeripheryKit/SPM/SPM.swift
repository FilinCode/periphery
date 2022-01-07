import Foundation
import SystemPackage
import Shared

public struct SPM {
    static let packageFile = "Package.swift"

    public static var isSupported: Bool {
        FilePath.current.appending(packageFile).exists
    }

    public struct Package: Decodable {
        public static func load() throws -> Self {
            let shell: Shell = inject()
            let jsonString = try shell.exec(["swift", "package", "describe", "--type", "json"], stderr: false)

            guard let jsonData = jsonString.data(using: .utf8) else {
                throw PeripheryError.packageError(message: "Failed to read swift package description.")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Package.self, from: jsonData)
        }

        public let name: String
        public let path: String

        let targets: [Target]

        public var swiftTargets: [Target] {
            targets.filter { $0.moduleType == "SwiftTarget" }
        }

        func clean() throws {
            let shell: Shell = inject()
            try shell.exec(["swift", "package", "clean"])
        }
    }

    public struct Target: Decodable {
        public let name: String

        let sources: [String]
        let path: String
        let moduleType: String

        public var sourcePaths: [FilePath] {
            let root = FilePath(path)
            return sources.map { root.appending($0) }
        }

        func build(additionalArguments: [String]) throws {
            let shell: Shell = inject()
            var args: [String] = ["swift", "build", "--target", name] + additionalArguments

            if SwiftVersion.current.version.isVersion(lessThan: "5.4") {
                args.append("--enable-test-discovery")
            }

            try shell.exec(args)
        }
    }
}

extension SPM.Package: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

extension SPM.Package: Equatable {
    public static func == (lhs: SPM.Package, rhs: SPM.Package) -> Bool {
        lhs.path == rhs.path
    }
}

extension SPM.Target: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension SPM.Target: Equatable {
    public static func == (lhs: SPM.Target, rhs: SPM.Target) -> Bool {
        lhs.name == rhs.name
    }
}
