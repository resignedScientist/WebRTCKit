import Foundation
import WebRTC

/// Utility class for modifying SDP content to ensure proper DTLS setup attributes
struct SDPModifier {
    
    /// DTLS setup roles
    enum DTLSSetup: String {
        case active = "active"
        case passive = "passive"
        case actpass = "actpass"
    }
    
    /// Modifies the SDP to set the correct DTLS setup attribute based on the role
    /// - Parameters:
    ///   - sdp: The original SDP
    ///   - setup: The DTLS setup role to set
    /// - Returns: Modified SDP with correct DTLS setup attribute
    static func modifyDTLSSetup(_ sdp: String, setup: DTLSSetup) -> String {
        var modifiedSDP = sdp
        
        // Pattern to match existing a=setup lines
        let setupPattern = "a=setup:(active|passive|actpass)"
        
        // New setup line to replace with
        let newSetupLine = "a=setup:\(setup.rawValue)"
        
        // Replace existing setup attributes
        if let regex = try? NSRegularExpression(pattern: setupPattern, options: []) {
            let range = NSRange(location: 0, length: modifiedSDP.utf16.count)
            modifiedSDP = regex.stringByReplacingMatches(
                in: modifiedSDP,
                options: [],
                range: range,
                withTemplate: newSetupLine
            )
        }
        
        // If no setup attribute was found, add it after each m= line
        if !modifiedSDP.contains("a=setup:") {
            modifiedSDP = addSetupAttributeToMediaSections(modifiedSDP, setup: setup)
        }
        
        return modifiedSDP
    }
    
    /// Adds setup attribute to all media sections if not present
    private static func addSetupAttributeToMediaSections(_ sdp: String, setup: DTLSSetup) -> String {
        var lines = sdp.components(separatedBy: .newlines)
        var modifiedLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            modifiedLines.append(line)
            
            // Add setup attribute after each m= line that doesn't already have one
            if line.hasPrefix("m=") {
                // Check if this media section already has a setup attribute
                let hasSetup = lines.dropFirst(index + 1).prefix(while: { !$0.hasPrefix("m=") }).contains { $0.hasPrefix("a=setup:") }
                
                if !hasSetup {
                    modifiedLines.append("a=setup:\(setup.rawValue)")
                }
            }
        }
        
        return modifiedLines.joined(separator: "\n")
    }
} 
