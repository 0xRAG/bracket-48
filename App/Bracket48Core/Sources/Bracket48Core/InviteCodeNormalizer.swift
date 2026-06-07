import Foundation

public enum InviteCodeNormalizer {
    private static let allowedURLHosts: Set<String> = [
        "bracket48.app",
        "www.bracket48.app"
    ]

    private static let allowedQueryNames: Set<String> = [
        "code",
        "invite",
        "invite_code"
    ]

    public static func normalizedInviteCode(from inviteText: String) -> String? {
        let trimmed = inviteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased()
        {
            return normalizedInviteCode(from: url, scheme: scheme)
        }

        return normalizeManualCode(trimmed)
    }

    private static func normalizedInviteCode(from url: URL, scheme: String) -> String? {
        switch scheme {
        case "https":
            guard let host = url.host?.lowercased(), allowedURLHosts.contains(host) else {
                return nil
            }
        case "bracket48":
            guard url.host?.lowercased() == "join" else {
                return nil
            }
        default:
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryCode = components?.queryItems?.first(where: { item in
            allowedQueryNames.contains(item.name.lowercased())
        })?.value {
            return normalizeManualCode(queryCode)
        }

        if let pathCode = pathInviteCode(from: url) {
            return normalizeManualCode(pathCode)
        }

        return nil
    }

    private static func pathInviteCode(from url: URL) -> String? {
        let pathComponents = url.pathComponents.filter { component in
            component != "/"
        }
        return pathComponents.last
    }

    private static func normalizeManualCode(_ value: String) -> String? {
        let uppercased = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (4...12).contains(uppercased.count) else {
            return nil
        }

        guard uppercased.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            return nil
        }

        return uppercased
    }
}
