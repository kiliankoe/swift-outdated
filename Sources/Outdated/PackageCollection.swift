import Foundation

struct PackageCollection: Encodable {
    var outdatedPackages: [OutdatedPackage]
    var ignoredPackages: [SwiftPackage]
}
