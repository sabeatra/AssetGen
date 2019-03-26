import Foundation

private let shouldOptimizeByDate = true

private func fileModificationDate(url: URL) -> Date? {
    do {
        let attr = try FileManager.default.attributesOfItem(atPath: url.path)
        return attr[FileAttributeKey.modificationDate] as? Date
    } catch {
        print(error)
        return nil
    }
}

private var header: String {
    get {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())

        return  """
                //Generated file, don't modify!
                //Generated on \(date)
                import UIKit
                private class Dummy {}
                """
    }
}

private func generateColors(colorNames: [String], outputURL: URL) throws {
    print("Generating colors...")
    
    let colorList = colorNames.map { "public static let \($0) = color(named: \"\($0)\")" }
    
    let source =    """
                    \(header)
                    private func color(named name: String) -> UIColor {
                        return UIColor(named: name, in: Bundle(for: Dummy.self), compatibleWith: nil) ?? .clear
                    }
                    public struct Color {
                        \(colorList.joined(separator: "\n\t"))
                    }
                    """
    try source.write(to: outputURL, atomically: true, encoding: .utf8)
}

private func generateImages(imageNames: [String], outputURL: URL) throws {
    print("Generating images ...")
    
    let imageList = imageNames.map { "public static let \($0) = image(named: \"\($0)\")" }
    
    let source =    """
                    \(header)
                    private func image(named name: String) -> UIImage? {
                        return UIImage(named: name, in: Bundle(for: Dummy.self), compatibleWith: nil)
                    }
                    public struct Image {
                        \(imageList.joined(separator: "\n\t"))
                    }
                    """
    try source.write(to: outputURL, atomically: true, encoding: .utf8)
}

private func generateAssets(
    outputFile: String,
    outputFolder: String,
    assetsFolder: String,
    assetExtension: String,
    generate: ([String], URL) throws -> Void)
{
    guard let sourcePath = ProcessInfo.processInfo.environment["SRCROOT"] else { return }
    guard let url = URL(string: sourcePath + assetsFolder) else { return print("Assets not found") }
    let outputURL = URL(fileURLWithPath: sourcePath + "/" + outputFolder + "/" + outputFile)
    
    do {
        // Get the directory contents urls (including subfolders urls)
        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: []
        )
        
        let folders = directoryContents.filter { $0.pathExtension == assetExtension }
        let names = folders.map { $0.deletingPathExtension().lastPathComponent }
        
        guard shouldOptimizeByDate else { return try generate(names, outputURL) }
        
        guard let sourceFileDate = fileModificationDate(url: outputURL) else { return print("Couldn't get \(outputFile) file date")}

        for url in folders {
            guard let date = fileModificationDate(url: url) else { continue }
            if date > sourceFileDate {
                return try generate(names, outputURL)
            }
        }
    } catch {
        print(error)
    }
}

struct Generate {
    
    static func all() {
        colors("/Lib")
        images("/Lib")
        images("/PassengerApp/App")
        images("/DriverApp/App")
    }
    
    static func colors(_ folder: String) {
        generateAssets(
            outputFile: "Colors.swift",
            outputFolder: "\(folder)/Generated",
            assetsFolder: "\(folder)/Colors.xcassets",
            assetExtension: "colorset",
            generate: generateColors
        )
    }
    
    static func images(_ folder: String) {
        generateAssets(
            outputFile: "Images.swift",
            outputFolder: "\(folder)/Generated",
            assetsFolder: "\(folder)/Images.xcassets",
            assetExtension: "imageset",
            generate: generateImages
        )
    }
}
