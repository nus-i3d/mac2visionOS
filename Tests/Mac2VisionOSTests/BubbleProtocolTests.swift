import Testing
@testable import Mac2VisionOS

@Test func normalizedKeyUppercasesAlphanumericPrefix() {
    #expect(BubbleProtocol.normalizedKey(" avp-123 ") == "AVP1")
}

@Test func serviceNameUsesNormalizedKey() {
    #expect(BubbleProtocol.serviceName(for: "avp1") == "mac2visionOS-AVP1")
}

@Test func validKeysNeedFourCharacters() {
    #expect(BubbleProtocol.isValidKey("AVP1"))
    #expect(!BubbleProtocol.isValidKey("AVP"))
}
