import Foundation

class ConcurrentDictionary<Key: Hashable & Sendable, Value: Sendable>: Collection, @unchecked Sendable {
    private var dictionary: [Key: Value]
    private let concurrentQueue = DispatchQueue(label: UUID().uuidString, attributes: .concurrent)

    var startIndex: Dictionary<Key, Value>.Index {
        concurrentQueue.sync {
            self.dictionary.startIndex
        }
    }

    var endIndex: Dictionary<Key, Value>.Index {
        concurrentQueue.sync {
            self.dictionary.endIndex
        }
    }

    init(dict: [Key: Value] = [Key: Value]()) {
        dictionary = dict
    }

    func index(after i: Dictionary<Key, Value>.Index) -> Dictionary<Key, Value>.Index {
        concurrentQueue.sync {
            self.dictionary.index(after: i)
        }
    }

    subscript(key: Key) -> Value? {
        set(newValue) {
            concurrentQueue.async(flags: .barrier) { [weak self] in
                self?.dictionary[key] = newValue
            }
        }
        get {
            concurrentQueue.sync {
                self.dictionary[key]
            }
        }
    }

    subscript(index: Dictionary<Key, Value>.Index) -> Dictionary<Key, Value>.Element {
        concurrentQueue.sync {
            self.dictionary[index]
        }
    }

    func removeValue(forKey key: Key) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeValue(forKey: key)
        }
    }

    func removeAll() {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.dictionary.removeAll()
        }
    }
}
