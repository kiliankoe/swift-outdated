import Foundation
import Outdated

struct PackageCollection: Encodable {
    var outdatedPackages: [OutdatedPackage]
    var ignoredPackages: [SwiftPackage]
}
