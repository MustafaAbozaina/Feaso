import UIKit

enum ImageAttachmentService {
    
    private static var attachmentsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let attachmentsPath = documentsPath.appendingPathComponent("Attachments", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: attachmentsPath.path) {
            try? FileManager.default.createDirectory(at: attachmentsPath, withIntermediateDirectories: true)
        }
        
        return attachmentsPath
    }
    
    /// Saves an image and returns the file name
    static func saveImage(_ image: UIImage, for transactionId: UUID) -> String? {
        // Compress image to JPEG with 80% quality
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        let fileName = "\(transactionId.uuidString).jpg"
        let fileURL = attachmentsDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            print("Failed to save attachment: \(error)")
            return nil
        }
    }
    
    /// Loads an image from the given file name
    static func loadImage(fileName: String) -> UIImage? {
        let fileURL = attachmentsDirectory.appendingPathComponent(fileName)
        
        guard let imageData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        return UIImage(data: imageData)
    }
    
    /// Deletes an image with the given file name
    static func deleteImage(fileName: String) {
        let fileURL = attachmentsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Checks if an attachment exists
    static func attachmentExists(fileName: String) -> Bool {
        let fileURL = attachmentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
