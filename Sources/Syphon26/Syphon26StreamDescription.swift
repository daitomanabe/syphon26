public struct Syphon26StreamDescription: Equatable, Sendable {
    public let streamID: Syphon26StreamID
    public let name: String
    public let appName: String?
    public let width: Int
    public let height: Int
    public let pixelFormat: Syphon26PixelFormat
    public let alphaMode: Syphon26AlphaMode
    public let colorPrimaries: Syphon26ColorPrimaries
    public let transferFunction: Syphon26TransferFunction
    public let controlPlaneServiceName: String

    public init(
        streamID: Syphon26StreamID,
        name: String,
        appName: String? = nil,
        width: Int,
        height: Int,
        pixelFormat: Syphon26PixelFormat,
        alphaMode: Syphon26AlphaMode = .premultiplied,
        colorPrimaries: Syphon26ColorPrimaries = .srgb,
        transferFunction: Syphon26TransferFunction = .srgb,
        controlPlaneServiceName: String = Syphon26.defaultControlPlaneServiceName
    ) throws {
        self.streamID = streamID
        self.name = try Syphon26Validation.validateStreamName(name)
        if let appName {
            self.appName = try Syphon26Validation.validateStreamName(appName, field: "appName")
        } else {
            self.appName = nil
        }
        try Syphon26Validation.validateDimensions(width: width, height: height)
        try Syphon26Validation.validatePixelFormat(pixelFormat)
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.alphaMode = alphaMode
        self.colorPrimaries = colorPrimaries
        self.transferFunction = transferFunction
        self.controlPlaneServiceName = try Syphon26Validation.validateControlPlaneServiceName(controlPlaneServiceName)
    }
}
