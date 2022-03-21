import Foundation

struct ResolvedV1: Decodable {
    let object: Object
    let version: Int

    struct Object: Decodable {
        let pins: [PinV1]
    }
}


struct ResolvedV2: Decodable {
    let pins: [PinV2]
    let version: Int
}
