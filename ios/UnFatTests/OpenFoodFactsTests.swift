import Foundation
import SwiftData
import Testing
@testable import UnFat

// Recorded-shape Open Food Facts v3 responses (trimmed to the requested fields). No test touches the network.
private enum OFFFixtures {
    static let wafer = """
    {
      "code": "8690504021052",
      "result": {"id": "product_found", "name": "Product found", "lg_name": "Ürün bulundu"},
      "status": "success",
      "product": {
        "code": "8690504021052",
        "product_name": "Chocolate Wafer",
        "product_name_tr": "Çikolatalı Gofret",
        "brands": "Ülker, Ulker",
        "serving_size": "36 g",
        "serving_quantity": 36,
        "image_front_small_url": "https://images.openfoodfacts.org/images/products/869/050/402/1052/front_tr.small.200.jpg",
        "nutriments": {
          "energy-kcal_100g": 520,
          "energy_100g": 2176,
          "proteins_100g": 6.5,
          "carbohydrates_100g": 62,
          "fat_100g": 26,
          "fiber_100g": 2.1
        }
      }
    }
    """

    /// No Turkish name, kJ only, values as strings with a decimal comma, serving only in the text.
    static let partialStrings = """
    {
      "code": "8690632012345",
      "result": {"id": "product_found"},
      "status": "success",
      "product": {
        "product_name": "Plain Biscuit",
        "product_name_tr": "",
        "brands": "",
        "serving_size": "2 biscuits (30g)",
        "nutriments": {
          "energy_100g": "1000",
          "proteins_100g": "7,5",
          "carbohydrates_100g": "70.2"
        }
      }
    }
    """

    /// Name only, no nutriments at all.
    static let noEnergy = """
    {
      "code": "8690000000024",
      "result": {"id": "product_found"},
      "status": "success",
      "product": {"product_name": "Mystery Snack", "nutriments": {"proteins_100g": 4}}
    }
    """

    static let notFound = """
    {
      "code": "8690000000017",
      "result": {"id": "product_not_found", "name": "No product found", "lg_name": "Ürün bulunamadı"},
      "status": "failure"
    }
    """
}

private struct StubTransport: HTTPTransport {
    let recorder: RequestRecorder
    var status = 200
    var body = Data()
    var error: (any Error)?

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        await recorder.record(request)
        if let error { throw error }
        return (body, status)
    }
}

private actor RequestRecorder {
    private(set) var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }
}

private actor FakeFetcher: OpenFoodFactsFetching {
    private var result: Result<OFFLookupResult, OFFError>
    private(set) var callCount = 0

    init(_ result: Result<OFFLookupResult, OFFError>) {
        self.result = result
    }

    func set(_ result: Result<OFFLookupResult, OFFError>) {
        self.result = result
    }

    func fetch(barcode: String) async throws -> OFFLookupResult {
        callCount += 1
        return try result.get()
    }
}

private func parse(_ json: String, barcode: String = "8690504021052", status: Int = 200) throws -> OFFLookupResult {
    try OFFParser.parse(Data(json.utf8), barcode: barcode, statusCode: status)
}

private func foundProduct(_ json: String, barcode: String = "8690504021052") throws -> OFFProduct {
    guard case .found(let product) = try parse(json, barcode: barcode) else {
        Issue.record("expected a found product")
        throw OFFError.badResponse
    }
    return product
}

@Suite("Open Food Facts parsing")
struct OpenFoodFactsParsingTests {
    @Test func fullProduct() throws {
        let product = try foundProduct(OFFFixtures.wafer)
        #expect(product.name == "Çikolatalı Gofret")
        #expect(product.brand == "Ülker")
        #expect(product.kcalPer100g == 520)
        #expect(product.proteinPer100g == 6.5)
        #expect(product.carbsPer100g == 62)
        #expect(product.fatPer100g == 26)
        #expect(product.fiberPer100g == 2.1)
        #expect(product.servingGrams == 36)
        #expect(product.servingText == "36 g")
        #expect(product.imageURLString?.hasPrefix("https://") == true)
        #expect(product.hasEnergy)
    }

    @Test func partialStringValuesKilojouleAndServingText() throws {
        let product = try foundProduct(OFFFixtures.partialStrings, barcode: "8690632012345")
        #expect(product.name == "Plain Biscuit")
        #expect(product.brand == nil)
        let kcal = try #require(product.kcalPer100g)
        #expect(abs(kcal - 1000 / 4.184) < 0.001)
        #expect(product.proteinPer100g == 7.5)
        #expect(product.carbsPer100g == 70.2)
        #expect(product.fatPer100g == nil)
        #expect(product.fiberPer100g == nil)
        #expect(product.servingGrams == 30)
    }

    @Test func productWithoutEnergyIsIncomplete() throws {
        let product = try foundProduct(OFFFixtures.noEnergy, barcode: "8690000000024")
        #expect(product.kcalPer100g == nil)
        #expect(!product.hasEnergy)
        #expect(product.proteinPer100g == 4)
        #expect(LoggableFood(product: product) == nil)
    }

    @Test func notFoundBodyAndStatus() throws {
        #expect(try parse(OFFFixtures.notFound, status: 404) == .notFound)
        #expect(try parse(OFFFixtures.notFound, status: 200) == .notFound)
        // 404 with a body that is not JSON still means "no such product".
        #expect(try OFFParser.parse(Data("Not Found".utf8), barcode: "8690000000017", statusCode: 404) == .notFound)
    }

    @Test func outageAndGarbageAreErrors() {
        #expect(throws: OFFError.badResponse) { try parse(OFFFixtures.wafer, status: 503) }
        #expect(throws: OFFError.badResponse) { try parse(OFFFixtures.wafer, status: 429) }
        #expect(throws: OFFError.badResponse) { try parse("<html>oops</html>") }
        #expect(throws: OFFError.badResponse) { try parse("{\"status\": \"success\"}") }
    }

    @Test func numberHandling() {
        #expect(OFFParser.number(12.5) == 12.5)
        #expect(OFFParser.number("12,5") == 12.5)
        #expect(OFFParser.number(" 3 ") == 3)
        #expect(OFFParser.number("") == nil)
        #expect(OFFParser.number("abc") == nil)
        #expect(OFFParser.number(-4) == nil)
        #expect(OFFParser.number("nan") == nil)
        #expect(OFFParser.number(nil) == nil)
    }

    @Test func servingGramsFromText() {
        #expect(OFFParser.grams(inServingText: "30 g") == 30)
        #expect(OFFParser.grams(inServingText: "2 biscuits (30g)") == 30)
        #expect(OFFParser.grams(inServingText: "12,5 gr") == 12.5)
        #expect(OFFParser.grams(inServingText: "250 ml") == nil)
        #expect(OFFParser.grams(inServingText: "1 kg") == nil)
        #expect(OFFParser.grams(inServingText: "1 portion") == nil)
    }
}

@Suite("Open Food Facts client")
struct OpenFoodFactsClientTests {
    @Test func barcodeValidation() {
        #expect(BarcodeValidator.normalized("8690504021052") == "8690504021052")
        #expect(BarcodeValidator.normalized(" 96385074 ") == "96385074")
        #expect(BarcodeValidator.normalized("12345678901234") == "12345678901234")
        #expect(BarcodeValidator.normalized("1234567") == nil)
        #expect(BarcodeValidator.normalized("123456789012345") == nil)
        #expect(BarcodeValidator.normalized("86905040X1052") == nil)
        #expect(BarcodeValidator.normalized("") == nil)
    }

    @Test func requestShape() throws {
        let request = OpenFoodFactsClient.request(barcode: "8690504021052", appVersion: "1.2")
        let url = try #require(request.url)
        #expect(url.host() == "world.openfoodfacts.org")
        #expect(url.path() == "/api/v3/product/8690504021052.json")
        #expect(url.absoluteString.contains("fields=code,product_name,product_name_tr,brands,nutriments,serving_size,serving_quantity,image_front_small_url"))
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "UnFat/1.2 (https://github.com/YusufUzun03/unfat)")
        #expect(request.timeoutInterval == 8)
    }

    @Test func fetchParsesThroughTransport() async throws {
        let recorder = RequestRecorder()
        let transport = StubTransport(recorder: recorder, body: Data(OFFFixtures.wafer.utf8))
        let client = OpenFoodFactsClient(transport: transport, appVersion: "1.0")
        let result = try await client.fetch(barcode: "8690504021052")
        guard case .found(let product) = result else {
            Issue.record("expected found")
            return
        }
        #expect(product.name == "Çikolatalı Gofret")
        #expect(await recorder.requests.count == 1)
    }

    @Test func notFoundThroughTransport() async throws {
        let transport = StubTransport(recorder: RequestRecorder(), status: 404, body: Data(OFFFixtures.notFound.utf8))
        let client = OpenFoodFactsClient(transport: transport, appVersion: "1.0")
        #expect(try await client.fetch(barcode: "8690000000017") == .notFound)
    }

    @Test func invalidBarcodeNeverHitsTheNetwork() async {
        let recorder = RequestRecorder()
        let client = OpenFoodFactsClient(transport: StubTransport(recorder: recorder), appVersion: "1.0")
        await #expect(throws: OFFError.invalidBarcode) { try await client.fetch(barcode: "123") }
        #expect(await recorder.requests.isEmpty)
    }

    @Test func transportFailureIsOffline() async {
        let transport = StubTransport(recorder: RequestRecorder(), error: URLError(.timedOut))
        let client = OpenFoodFactsClient(transport: transport, appVersion: "1.0")
        await #expect(throws: OFFError.offline) { try await client.fetch(barcode: "8690504021052") }
    }
}

@Suite("Barcode lookup service")
@MainActor
struct BarcodeLookupServiceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let wafer: OFFProduct
    let barcode = "8690504021052"

    final class TestClock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        wafer = try {
            guard case .found(let product) = try OFFParser.parse(Data(OFFFixtures.wafer.utf8), barcode: "8690504021052") else {
                throw OFFError.badResponse
            }
            return product
        }()
    }

    private func service(_ fetcher: FakeFetcher, clock: TestClock) -> BarcodeLookupService {
        BarcodeLookupService(fetcher: fetcher, now: { clock.now })
    }

    private func cachedRows() throws -> [CachedProduct] {
        try context.fetch(FetchDescriptor<CachedProduct>())
    }

    @Test func customFoodWithBarcodeWinsWithoutNetwork() async throws {
        let custom = CustomFood(name: "Annemin böreği", barcode: barcode, kcalPer100g: 300, proteinPer100g: 8, carbsPer100g: 30, fatPer100g: 15)
        context.insert(custom)
        try context.save()
        let fetcher = FakeFetcher(.success(.found(wafer)))
        let outcome = try await service(fetcher, clock: TestClock(start)).lookup(barcode, in: context)
        guard case .customFood(let food) = outcome else {
            Issue.record("expected the custom food")
            return
        }
        #expect(food.foodRef == custom.foodRef)
        #expect(food.source == .custom)
        #expect(await fetcher.callCount == 0)
        #expect(try cachedRows().isEmpty)
    }

    @Test func networkResultIsCachedAndFreshCacheSkipsNetwork() async throws {
        let fetcher = FakeFetcher(.success(.found(wafer)))
        let clock = TestClock(start)
        let service = service(fetcher, clock: clock)

        let first = try await service.lookup(barcode, in: context)
        #expect(first == .product(wafer))
        #expect(await fetcher.callCount == 1)

        let rows = try cachedRows()
        #expect(rows.count == 1)
        #expect(rows.first?.name == "Çikolatalı Gofret")
        #expect(rows.first?.kcalPer100g == 520)
        #expect(rows.first?.servingGrams == 36)
        #expect(rows.first?.isNotFound == false)

        clock.now = start.addingTimeInterval(29 * 24 * 3600)
        let second = try await service.lookup(barcode, in: context)
        #expect(second == .product(wafer))
        #expect(await fetcher.callCount == 1)
    }

    @Test func staleCacheRefetchesAndUpdatesTheSameRow() async throws {
        let fetcher = FakeFetcher(.success(.found(wafer)))
        let clock = TestClock(start)
        let service = service(fetcher, clock: clock)
        _ = try await service.lookup(barcode, in: context)

        var updated = wafer
        updated.kcalPer100g = 510
        await fetcher.set(.success(.found(updated)))
        clock.now = start.addingTimeInterval(31 * 24 * 3600)
        let outcome = try await service.lookup(barcode, in: context)

        #expect(outcome == .product(updated))
        #expect(await fetcher.callCount == 2)
        let rows = try cachedRows()
        #expect(rows.count == 1)
        #expect(rows.first?.kcalPer100g == 510)
        #expect(rows.first?.fetchedAt == clock.now)
    }

    @Test func notFoundIsCachedForOneDay() async throws {
        let fetcher = FakeFetcher(.success(.notFound))
        let clock = TestClock(start)
        let service = service(fetcher, clock: clock)

        #expect(try await service.lookup(barcode, in: context) == .notFound(barcode: barcode))
        #expect(try cachedRows().first?.isNotFound == true)

        clock.now = start.addingTimeInterval(23 * 3600)
        #expect(try await service.lookup(barcode, in: context) == .notFound(barcode: barcode))
        #expect(await fetcher.callCount == 1)

        // A day later the product may have been added to OFF in the meantime.
        await fetcher.set(.success(.found(wafer)))
        clock.now = start.addingTimeInterval(25 * 3600)
        #expect(try await service.lookup(barcode, in: context) == .product(wafer))
        #expect(await fetcher.callCount == 2)
        let rows = try cachedRows()
        #expect(rows.count == 1)
        #expect(rows.first?.isNotFound == false)
    }

    @Test func networkErrorsPropagateAndLeaveNoCache() async throws {
        let fetcher = FakeFetcher(.failure(.offline))
        let service = service(fetcher, clock: TestClock(start))
        await #expect(throws: OFFError.offline) { try await service.lookup(barcode, in: context) }
        #expect(try cachedRows().isEmpty)
        await #expect(throws: OFFError.invalidBarcode) { try await service.lookup("12", in: context) }
    }

    @Test func freshnessWindows() {
        let found = CachedProduct(barcode: barcode, fetchedAt: start)
        let missing = CachedProduct(barcode: barcode, fetchedAt: start)
        missing.isNotFound = true
        #expect(BarcodeLookupService.isFresh(found, now: start.addingTimeInterval(30 * 24 * 3600 - 1)))
        #expect(!BarcodeLookupService.isFresh(found, now: start.addingTimeInterval(30 * 24 * 3600)))
        #expect(BarcodeLookupService.isFresh(missing, now: start.addingTimeInterval(24 * 3600 - 1)))
        #expect(!BarcodeLookupService.isFresh(missing, now: start.addingTimeInterval(24 * 3600)))
    }

    @Test func loggableFoodFromProduct() throws {
        let food = try #require(LoggableFood(product: wafer))
        #expect(food.foodRef == "off:8690504021052")
        #expect(food.source == .openFoodFacts)
        #expect(food.name == "Çikolatalı Gofret")
        #expect(food.kcalPer100g == 520)
        #expect(food.fiberPer100g == 2.1)
        #expect(food.servings.first?.grams == 36)
        #expect(food.portionUnits.first?.kind == .serving)

        var noServing = wafer
        noServing.servingGrams = nil
        let plain = try #require(LoggableFood(product: noServing))
        #expect(plain.servings.isEmpty)
        #expect(plain.defaultGrams == 100)
    }

    @Test func customDraftFromPartialProduct() throws {
        let partial = try foundProduct(OFFFixtures.partialStrings, barcode: "8690632012345")
        let draft = CustomFoodDraft(product: partial)
        #expect(draft.barcode == "8690632012345")
        #expect(draft.name == "Plain Biscuit")
        #expect(draft.proteinText == "7.5")
        #expect(draft.fatText.isEmpty)
        #expect(draft.servingGramsText == "30")

        let empty = CustomFoodDraft(barcode: "8690000000017")
        #expect(empty.barcode == "8690000000017")
        #expect(empty.name.isEmpty)
        #expect(!empty.isValid)
    }

    @Test func savedCustomFoodKeepsTheBarcodeAndIsFoundNextScan() async throws {
        var draft = CustomFoodDraft(barcode: "8690000000017")
        draft.name = "Köy ekmeği"
        draft.kcalText = "250"
        let food = try FoodLogService.createCustomFood(draft, in: context)
        #expect(food.barcode == "8690000000017")

        let fetcher = FakeFetcher(.success(.notFound))
        let outcome = try await service(fetcher, clock: TestClock(start)).lookup("8690000000017", in: context)
        #expect(outcome == .customFood(LoggableFood(custom: food)))
        #expect(await fetcher.callCount == 0)
    }

    @Test func searchFindsCachedProducts() async throws {
        let fetcher = FakeFetcher(.success(.found(wafer)))
        _ = try await service(fetcher, clock: TestClock(start)).lookup(barcode, in: context)
        let missing = CachedProduct(barcode: "8690000000017", fetchedAt: start)
        missing.isNotFound = true
        context.insert(missing)

        let catalog = SeedCatalog(foods: [], exercises: [])
        let rows = try cachedRows()
        let hits = FoodLogService.search("gofret", customFoods: [], cachedProducts: rows, catalog: catalog)
        #expect(hits.map(\.foodRef) == ["off:8690504021052"])
        #expect(FoodLogService.search("ülker", customFoods: [], cachedProducts: rows, catalog: catalog).count == 1)
        #expect(FoodLogService.search("zzz", customFoods: [], cachedProducts: rows, catalog: catalog).isEmpty)
    }
}

@Suite("Barcode launch routes")
struct BarcodeRouteTests {
    @Test func routesParse() {
        #expect(LaunchRoute(rawValue: "barcode-scanner")?.destination == .screen(.barcode(.scanner)))
        #expect(LaunchRoute(rawValue: "product-card")?.destination == .screen(.barcode(.productCard)))
        #expect(LaunchRoute(rawValue: "product-partial")?.destination == .screen(.barcode(.productPartial)))
        #expect(LaunchRoute(rawValue: "product-not-found")?.destination == .screen(.barcode(.productNotFound)))
    }
}
