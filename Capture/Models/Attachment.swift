import Foundation
import SwiftData

@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    var captureId: UUID
    var type: AttachmentType
    var filename: String
    var localPath: String?
    var url: String?
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        captureId: UUID,
        type: AttachmentType,
        filename: String,
        localPath: String? = nil,
        url: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.captureId = captureId
        self.type = type
        self.filename = filename
        self.localPath = localPath
        self.url = url
        self.thumbnailData = thumbnailData
    }
}
