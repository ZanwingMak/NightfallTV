import Foundation

struct VideoCredit: Decodable, Identifiable {
    let scene: SceneKind
    let title: String
    let creator: String
    let license: String
    let licenseURL: String
    let sourceURL: String
    let changes: String
    var id: String { scene.rawValue }

    static let all: [VideoCredit] = {
        guard let url = Bundle.main.url(forResource: "credits", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([VideoCredit].self, from: data)) ?? []
    }()
}

struct AudioCredit: Decodable, Identifiable {
    let sound: SoundKind
    let title: String
    let creator: String
    let license: String
    let licenseURL: String
    let sourceURL: String
    let sourceFormat: String
    let changes: String
    var id: String { sound.rawValue }

    static let all: [AudioCredit] = {
        guard let url = Bundle.main.url(forResource: "audio-credits", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([AudioCredit].self, from: data)) ?? []
    }()
}
