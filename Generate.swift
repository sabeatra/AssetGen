import Foundation

enum GenerationError: Error {
    case colorJson
}

private func fileModificationDate(url: URL) -> Date? {
    do {
        let attr = try FileManager.default.attributesOfItem(atPath: url.path)
        return attr[FileAttributeKey.modificationDate] as? Date
    } catch {
        return nil
    }
}

private func colorFromJson(url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    
    struct Components: Decodable {
        let red: String
        let blue: String
        let green: String
        let alpha: String
    }

    struct ColorDescriptor: Decodable {
        let components: Components
    }
    struct ColorPayload: Decodable {
        let color: ColorDescriptor
    }
    struct Payload: Decodable {
        let colors: [ColorPayload]
    }
    let payload = try JSONDecoder().decode(Payload.self, from: data)
    guard let components = payload.colors.first?.color.components else { throw GenerationError.colorJson }
    let hex = components.red + [components.green, components.blue].map({ $0.replacingOccurrences(of: "0x", with: "") }).joined()
    return "UIColor(rgb: \(hex), alpha: \(components.alpha)"
}


private func generateColors(folders: [URL], sourceURL: URL) throws {
    print("Generating colors...")
    
    let colorList: [String] = try folders.map { url in
        let fileURL = url.appendingPathComponent("Contents.json")
        let colorString = try colorFromJson(url: fileURL)
        let colorName = url.deletingPathExtension().lastPathComponent
        return "public static let \(colorName) = \(colorString))"
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    let date = dateFormatter.string(from: Date())
    
    let source = """
//Generated file, don't modify!
//Generated on \(date)
import Foundation
    
public struct Color {
    \(colorList.joined(separator: "\n\t"))
}
"""
    
    try source.write(to: sourceURL, atomically: true, encoding: .utf8)
}

private let shouldOptimizeByDate = true

struct Generate {
    
    static func all() {
        colors()
    }
    
    static func colors() {
        let source = "Colors.swift"
        guard let sourcePath = ProcessInfo.processInfo.environment["SRCROOT"] else { return }
        guard let url = URL(string: sourcePath + "/Lib/colors.xcassets") else { return print("Color assets not found") }
        let sourceURL = URL(fileURLWithPath: sourcePath + "/Lib/Generated/\(source)")
        guard let sourceFileDate = fileModificationDate(url: sourceURL) else { return print("Couldn't get \(source) file date")}

        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil, options: []
            )
            
            let colorFolders = directoryContents.filter { $0.pathExtension == "colorset" }
            guard shouldOptimizeByDate else { return try generateColors(folders: colorFolders, sourceURL: sourceURL) }
            
            for url in colorFolders {
                guard let date = fileModificationDate(url: url) else { continue }
                if date > sourceFileDate {
                    return try generateColors(folders: colorFolders, sourceURL: sourceURL)
                }
            }
        } catch {
            print(error)
        }
    }
}


