import Testing

@testable import Bracket48Core

@Suite("InviteCodeNormalizer")
struct InviteCodeNormalizerTests {
    @Test("accepts manual invite codes")
    func acceptsManualInviteCodes() {
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: " demo88dd ") == "DEMO88DD")
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "ABCD") == "ABCD")
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "ABC123XYZ789") == "ABC123XYZ789")
    }

    @Test("accepts Bracket 48 universal links and custom scheme links")
    func acceptsAppInviteLinks() {
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "https://bracket48.app/join/?code=demo88dd") == "DEMO88DD")
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "https://www.bracket48.app/join/DEMO88DD") == "DEMO88DD")
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "bracket48://join?code=demo88dd") == "DEMO88DD")
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "https://bracket48.app/join/?invite_code=DEMO88DD") == "DEMO88DD")
    }

    @Test("rejects malformed and hostile invite inputs")
    func rejectsMalformedAndHostileInputs() {
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "ABC") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "ABC123XYZ7890") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "DEMO-88DD") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "DEMO88DD<script>") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "https://evil.example/join?code=DEMO88DD") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "http://bracket48.app/join?code=DEMO88DD") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "javascript:alert(1)?code=DEMO88DD") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "bracket48://profile?code=DEMO88DD") == nil)
        #expect(InviteCodeNormalizer.normalizedInviteCode(from: "https://bracket48.app/join/?code=DEMO%2D88DD") == nil)
    }
}
