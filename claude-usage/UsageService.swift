import Foundation

@Observable
final class UsageService: @unchecked Sendable {
    var sessionUsage: Double?
    var sessionResetsAt: Date?
    var weeklyUsage: Double?
    var weeklyResetsAt: Date?
    var opusUsage: Double?
    var extraUsageEnabled: Bool?
    var monthlyLimitCents: Int?
    var usedCreditsCents: Int?
    var currency: String?
    var isLoading = false
    var errorMessage: String?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        isoFractionalFormatter.date(from: string) ?? isoFormatter.date(from: string)
    }

    private func makeRequest(url: URL, sessionKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        return request
    }

    private func fetchJSON(request: URLRequest) async throws -> [String: Any]? {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            errorMessage = "Invalid response"
            return nil
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            errorMessage = "Session expired — update your session key in Settings"
            return nil
        default:
            errorMessage = "Server error (\(http.statusCode))"
            return nil
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            errorMessage = "Unexpected response format"
            return nil
        }
        return json
    }

    func fetchUsage(sessionKey: String, orgId: String) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let base = "https://claude.ai/api/organizations/\(orgId)"
        guard let usageURL = URL(string: "\(base)/usage"),
              let overageURL = URL(string: "\(base)/overage_spend_limit") else {
            errorMessage = "Invalid organization ID"
            return
        }

        let usageReq = makeRequest(url: usageURL, sessionKey: sessionKey)
        let overageReq = makeRequest(url: overageURL, sessionKey: sessionKey)

        do {
            async let usageJSON = fetchJSON(request: usageReq)
            async let overageJSON = fetchJSON(request: overageReq)

            let (usage, overage) = try await (usageJSON, overageJSON)

            if let json = usage {
                if let fiveHour = json["five_hour"] as? [String: Any] {
                    sessionUsage = (fiveHour["utilization"] as? NSNumber)?.doubleValue
                    if let str = fiveHour["resets_at"] as? String {
                        sessionResetsAt = Self.parseDate(str)
                    }
                }

                if let sevenDay = json["seven_day"] as? [String: Any] {
                    weeklyUsage = (sevenDay["utilization"] as? NSNumber)?.doubleValue
                    if let str = sevenDay["resets_at"] as? String {
                        weeklyResetsAt = Self.parseDate(str)
                    }
                }

                if let opus = json["seven_day_opus"] as? [String: Any] {
                    opusUsage = (opus["utilization"] as? NSNumber)?.doubleValue
                }
            }

            if let json = overage {
                extraUsageEnabled = json["is_enabled"] as? Bool
                monthlyLimitCents = (json["monthly_credit_limit"] as? NSNumber)?.intValue
                usedCreditsCents = (json["used_credits"] as? NSNumber)?.intValue
                currency = json["currency"] as? String
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
