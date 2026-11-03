import Foundation

// Open Food Facts API v3 client. Data is ODbL (attribution shown on the product card).
// Network access goes through `HTTPTransport`, so tests inject canned responses.

/// What can go wrong with a lookup. "Product not found" is a result, not an error.
enum OFFError: Error, Equatable, Sendable {
    /// The text is not an 8-14 digit barcode.
    case invalidBarcode
    /// No connection, timeout or any other transport failure; worth a retry.
    case offline
    /// The server answered with something that is not a usable v3 response.
    case badResponse
}

/// A product as OFF describes it, reduced to what the app uses. Nutrient values are per 100 g;
/// a missing value is nil (kcal missing = incomplete product).
struct OFFProduct: Equatable, Sendable {
    var barcode: String
    var name: String?
    var brand: String?
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    /// OFF `serving_size` text as written ("30 g", "2 biscuits (30g)"), display only.
    var servingText: String?
    /// Grams of one serving when OFF gave a quantity or the text contains grams.
    var servingGrams: Double?
    var imageURLString: String?

    /// kcal is required to log the product; without it the card offers the custom food form.
    var hasEnergy: Bool { kcalPer100g != nil }
}

enum OFFLookupResult: Equatable, Sendable {
    case found(OFFProduct)
    case notFound
}

/// Barcode text rules: digits only, 8-14 of them (EAN-8, UPC-E, UPC-A, EAN-13, ITF-14).
enum BarcodeValidator {
    static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...14).contains(trimmed.count), trimmed.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        return trimmed
    }
}

/// Seam between the lookup service and the network.
protocol OpenFoodFactsFetching: Sendable {
    func fetch(barcode: String) async throws -> OFFLookupResult
}

/// One HTTP round trip. Returns the body and status code for any status; throws only on transport failure.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OFFError.badResponse }
        return (data, http.statusCode)
    }
}

struct OpenFoodFactsClient: OpenFoodFactsFetching {
    static let timeout: TimeInterval = 8
    static let fields = "code,product_name,product_name_tr,brands,nutriments,serving_size,serving_quantity,image_front_small_url"
    static let repositoryURL = "https://github.com/YusufUzun03/unfat"

    let transport: any HTTPTransport
    let appVersion: String

    init(transport: any HTTPTransport = URLSessionTransport(), appVersion: String = OpenFoodFactsClient.bundleVersion) {
        self.transport = transport
        self.appVersion = appVersion
    }

    static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static func userAgent(appVersion: String) -> String {
        "UnFat/\(appVersion) (\(repositoryURL))"
    }

    /// The v3 request for a validated barcode.
    static func request(barcode: String, appVersion: String) -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v3/product/\(barcode).json"
        components.queryItems = [URLQueryItem(name: "fields", value: fields)]
        var request = URLRequest(url: components.url ?? URL(fileURLWithPath: "/"), timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(userAgent(appVersion: appVersion), forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func fetch(barcode: String) async throws -> OFFLookupResult {
        guard let code = BarcodeValidator.normalized(barcode) else { throw OFFError.invalidBarcode }
        let request = Self.request(barcode: code, appVersion: appVersion)
        let data: Data
        let status: Int
        do {
            (data, status) = try await transport.send(request)
        } catch let error as OFFError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw OFFError.offline
        }
        return try OFFParser.parse(data, barcode: code, statusCode: status)
    }
}

/// Parses a v3 product response. Numbers may arrive as JSON numbers or as strings, so the JSON is
/// read dynamically instead of through `Codable`.
enum OFFParser {
    static func parse(_ data: Data, barcode: String, statusCode: Int = 200) throws -> OFFLookupResult {
        // v3 answers an unknown barcode with HTTP 404 and a JSON body; anything else non-2xx is an outage.
        guard (200..<300).contains(statusCode) || statusCode == 404 else { throw OFFError.badResponse }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            if statusCode == 404 { return .notFound }
            throw OFFError.badResponse
        }
        let resultID = (root["result"] as? [String: Any])?["id"] as? String
        let status = root["status"] as? String
        let product = root["product"] as? [String: Any]

        if resultID == "product_not_found" { return .notFound }
        guard let product else {
            if status == "failure" || statusCode == 404 { return .notFound }
            throw OFFError.badResponse
        }
        return .found(makeProduct(product, barcode: barcode))
    }

    private static func makeProduct(_ product: [String: Any], barcode: String) -> OFFProduct {
        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        let servingText = text(product["serving_size"])
        let servingGrams = positiveNumber(product["serving_quantity"]) ?? servingText.flatMap(grams(inServingText:))
        return OFFProduct(
            barcode: barcode,
            name: text(product["product_name_tr"]) ?? text(product["product_name"]),
            brand: text(product["brands"])?
                .split(separator: ",")
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .flatMap { $0.isEmpty ? nil : $0 },
            kcalPer100g: kcal(nutriments),
            proteinPer100g: number(nutriments["proteins_100g"]),
            carbsPer100g: number(nutriments["carbohydrates_100g"]),
            fatPer100g: number(nutriments["fat_100g"]),
            fiberPer100g: number(nutriments["fiber_100g"]),
            servingText: servingText,
            servingGrams: servingGrams,
            imageURLString: text(product["image_front_small_url"])
        )
    }

    /// `energy-kcal_100g`, else `energy_100g` (kJ) / 4.184.
    private static func kcal(_ nutriments: [String: Any]) -> Double? {
        if let kcal = number(nutriments["energy-kcal_100g"]) { return kcal }
        if let kilojoules = number(nutriments["energy_100g"]) { return kilojoules / 4.184 }
        return nil
    }

    /// A finite, non-negative number from a JSON number or a string ("12,5" and "12.5" both work).
    static func number(_ value: Any?) -> Double? {
        let parsed: Double?
        switch value {
        case let number as NSNumber:
            parsed = number.doubleValue
        case let string as String:
            let cleaned = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            parsed = cleaned.isEmpty ? nil : Double(cleaned)
        default:
            parsed = nil
        }
        guard let parsed, parsed.isFinite, parsed >= 0 else { return nil }
        return parsed
    }

    private static func positiveNumber(_ value: Any?) -> Double? {
        guard let value = number(value), value > 0 else { return nil }
        return value
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Grams written in a serving text: "30 g", "2 biscuits (30g)", "12,5 gr". Millilitres do not count.
    static func grams(inServingText text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram)\b"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return positiveNumber(String(text[range]))
    }
}
