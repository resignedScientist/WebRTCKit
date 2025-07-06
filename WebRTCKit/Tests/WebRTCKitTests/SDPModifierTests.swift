import XCTest
@testable import WebRTCKit

final class SDPModifierTests: XCTestCase {
    
    func testModifyDTLSSetupToActive() {
        // Test SDP with existing setup attribute
        let inputSDP = """
        v=0
        o=- 123456789 123456789 IN IP4 192.168.1.1
        s=-
        t=0 0
        m=audio 9 UDP/TLS/RTP/SAVPF 111
        a=setup:passive
        m=video 9 UDP/TLS/RTP/SAVPF 96
        a=setup:passive
        """
        
        let modifiedSDP = SDPModifier.modifyDTLSSetup(inputSDP, setup: .active)
        
        XCTAssertTrue(modifiedSDP.contains("a=setup:active"))
        XCTAssertFalse(modifiedSDP.contains("a=setup:passive"))
        
        // Count occurrences - should have 2 active setups (for audio and video)
        let activeCount = modifiedSDP.components(separatedBy: "a=setup:active").count - 1
        XCTAssertEqual(activeCount, 2)
    }
    
    func testModifyDTLSSetupToPassive() {
        // Test SDP with existing setup attribute
        let inputSDP = """
        v=0
        o=- 123456789 123456789 IN IP4 192.168.1.1
        s=-
        t=0 0
        m=audio 9 UDP/TLS/RTP/SAVPF 111
        a=setup:active
        m=video 9 UDP/TLS/RTP/SAVPF 96
        a=setup:active
        """
        
        let modifiedSDP = SDPModifier.modifyDTLSSetup(inputSDP, setup: .passive)
        
        XCTAssertTrue(modifiedSDP.contains("a=setup:passive"))
        XCTAssertFalse(modifiedSDP.contains("a=setup:active"))
        
        // Count occurrences - should have 2 passive setups (for audio and video)
        let passiveCount = modifiedSDP.components(separatedBy: "a=setup:passive").count - 1
        XCTAssertEqual(passiveCount, 2)
    }
    
    func testAddDTLSSetupWhenMissing() {
        // Test SDP without setup attributes
        let inputSDP = """
        v=0
        o=- 123456789 123456789 IN IP4 192.168.1.1
        s=-
        t=0 0
        m=audio 9 UDP/TLS/RTP/SAVPF 111
        a=sendrecv
        m=video 9 UDP/TLS/RTP/SAVPF 96
        a=sendrecv
        """
        
        let modifiedSDP = SDPModifier.modifyDTLSSetup(inputSDP, setup: .active)
        
        XCTAssertTrue(modifiedSDP.contains("a=setup:active"))
        
        // Count occurrences - should have 2 active setups added (for audio and video)
        let activeCount = modifiedSDP.components(separatedBy: "a=setup:active").count - 1
        XCTAssertEqual(activeCount, 2)
    }
    
    func testMixedSetupAttributes() {
        // Test SDP with mixed setup attributes
        let inputSDP = """
        v=0
        o=- 123456789 123456789 IN IP4 192.168.1.1
        s=-
        t=0 0
        m=audio 9 UDP/TLS/RTP/SAVPF 111
        a=setup:actpass
        m=video 9 UDP/TLS/RTP/SAVPF 96
        a=setup:passive
        """
        
        let modifiedSDP = SDPModifier.modifyDTLSSetup(inputSDP, setup: .active)
        
        XCTAssertTrue(modifiedSDP.contains("a=setup:active"))
        XCTAssertFalse(modifiedSDP.contains("a=setup:passive"))
        XCTAssertFalse(modifiedSDP.contains("a=setup:actpass"))
        
        // Count occurrences - should have 2 active setups (for audio and video)
        let activeCount = modifiedSDP.components(separatedBy: "a=setup:active").count - 1
        XCTAssertEqual(activeCount, 2)
    }
} 