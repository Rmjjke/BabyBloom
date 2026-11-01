import XCTest
@testable import BabyBloom

/// Checks length-for-age against WHO's own published tables.
///
/// The reference lengths are WHO's expanded percentile and z-score tables
/// (lhfa-*-percentiles- and lhfa-*-zscore-expanded-tables.xlsx, who.int), three
/// decimals. They are computed by WHO from the same LMS rows the app stores, so
/// a wrong formula, a slipped row or a bad interpolation grid would show here.
/// Days 0, 45 and 730 are stored nodes; 183 (six months) and 365 fall between
/// nodes and exercise the interpolation.
final class WHOLengthStandardTests: XCTestCase {

    /// (day, isMale, percentile, length in cm) — P3 / P50 / P97.
    private static let percentiles: [(day: Int, male: Bool, p: Double, cm: Double)] = [
        (0, true, 3, 46.324), (0, true, 50, 49.884), (0, true, 97, 53.445),
        (45, true, 3, 52.892), (45, true, 50, 56.606), (45, true, 97, 60.319),
        (183, true, 3, 63.617), (183, true, 50, 67.644), (183, true, 97, 71.67),
        (365, true, 3, 71.27), (365, true, 50, 75.739), (365, true, 97, 80.208),
        (730, true, 3, 82.057), (730, true, 50, 87.802), (730, true, 97, 93.547),
        (0, false, 3, 45.644), (0, false, 50, 49.148), (0, false, 97, 52.651),
        (45, false, 3, 51.649), (45, false, 50, 55.402), (45, false, 97, 59.155),
        (183, false, 3, 61.487), (183, false, 50, 65.751), (183, false, 97, 70.015),
        (365, false, 3, 69.163), (365, false, 50, 74.005), (365, false, 97, 78.847),
        (730, false, 3, 80.335), (730, false, 50, 86.401), (730, false, 97, 92.467)
    ]

    /// (day, isMale, z, length in cm) — the −3 / −2 / 0 / +2 SD lines.
    private static let sdLines: [(day: Int, male: Bool, z: Double, cm: Double)] = [
        (0, true, -3, 44.205), (0, true, -2, 46.098), (0, true, 0, 49.884), (0, true, 2, 53.67),
        (45, true, -3, 50.682), (45, true, -2, 52.657), (45, true, 0, 56.606), (45, true, 2, 60.554),
        (183, true, -3, 61.221), (183, true, -2, 63.362), (183, true, 0, 67.644), (183, true, 2, 71.925),
        (365, true, -3, 68.611), (365, true, -2, 70.987), (365, true, 0, 75.739), (365, true, 2, 80.491),
        (730, true, -3, 78.638), (730, true, -2, 81.693), (730, true, 0, 87.802), (730, true, 2, 93.911),
        (0, false, -3, 43.56), (0, false, -2, 45.422), (0, false, 0, 49.148), (0, false, 2, 52.873),
        (45, false, -3, 49.415), (45, false, -2, 51.411), (45, false, 0, 55.402), (45, false, 2, 59.393),
        (183, false, -3, 58.95), (183, false, -2, 61.217), (183, false, 0, 65.751), (183, false, 2, 70.285),
        (365, false, -3, 66.281), (365, false, -2, 68.856), (365, false, 0, 74.005), (365, false, 2, 79.154),
        (730, false, -3, 76.725), (730, false, -2, 79.95), (730, false, 0, 86.401), (730, false, 2, 92.851)
    ]

    /// The card's criterion: a published P3 / P50 / P97 length scores back to
    /// 3 / 50 / 97 within ±0.1. Uses the unrounded CDF — the user-facing
    /// `lengthPercentile` rounds to a whole number and would pass trivially.
    func testPublishedPercentileLengthsScoreBackWithinATenth() throws {
        for point in Self.percentiles {
            let z = try XCTUnwrap(WHOGrowthStandard.lengthZScore(
                lengthCm: point.cm, ageDays: point.day, isMale: point.male),
                "day \(point.day), male=\(point.male)")
            XCTAssertEqual(WHOGrowthStandard.rawPercentile(fromZ: z), point.p, accuracy: 0.1,
                           "day \(point.day), male=\(point.male), P\(Int(point.p))")
        }
    }

    /// The rounded, user-facing number for the same points.
    func testLengthPercentileReadsThePublishedCentile() {
        for point in Self.percentiles {
            XCTAssertEqual(WHOGrowthStandard.lengthPercentile(
                lengthCm: point.cm, ageDays: point.day, isMale: point.male), point.p,
                "day \(point.day), male=\(point.male)")
        }
    }

    /// The same budget the weight tests use: 0.02 z covers the 3-decimal
    /// rounding plus the grid's interpolation error with room to spare.
    func testZScoresMatchPublishedSDLines() throws {
        for point in Self.sdLines {
            let z = try XCTUnwrap(WHOGrowthStandard.lengthZScore(
                lengthCm: point.cm, ageDays: point.day, isMale: point.male))
            XCTAssertEqual(z, point.z, accuracy: 0.02, "day \(point.day), male=\(point.male)")
        }
    }

    /// The inverse against the same table. 0.02 z is at most 0.07 cm here
    /// (M × S peaks at 730 days: 87.8 × 0.0348 ≈ 3.06 cm per z), so 0.07 is
    /// the z budget converted at the worst rate, not a looser test.
    func testLengthAtZMatchesPublishedSDLines() throws {
        for point in Self.sdLines {
            let cm = try XCTUnwrap(WHOGrowthStandard.length(
                atZ: point.z, ageDays: point.day, isMale: point.male))
            XCTAssertEqual(cm, point.cm, accuracy: 0.07, "day \(point.day), male=\(point.male), z=\(point.z)")
        }
    }

    /// Same range rule as weight: nothing before term, nothing past two years,
    /// nothing for a non-positive length.
    func testOutsideTheTableThereIsNoAnswer() {
        XCTAssertNil(WHOGrowthStandard.lengthPercentile(lengthCm: 50, ageDays: -1, isMale: true))
        XCTAssertNil(WHOGrowthStandard.lengthPercentile(lengthCm: 90, ageDays: 731, isMale: false))
        XCTAssertNil(WHOGrowthStandard.lengthPercentile(lengthCm: 0, ageDays: 30, isMale: true))
        XCTAssertNotNil(WHOGrowthStandard.lengthPercentile(lengthCm: 87, ageDays: 730, isMale: true))
    }

    /// Boys and girls are different tables — a swapped flag would still pass
    /// a test that only checks one sex.
    func testTheSexFlagPicksTheRightTable() throws {
        let boy = try XCTUnwrap(WHOGrowthStandard.lengthLMS(ageDays: 0, isMale: true))
        let girl = try XCTUnwrap(WHOGrowthStandard.lengthLMS(ageDays: 0, isMale: false))
        XCTAssertEqual(boy.m, 49.8842, accuracy: 1e-9)
        XCTAssertEqual(girl.m, 49.1477, accuracy: 1e-9)
    }

    /// Weight scoring did not move when the lookup was shared with length.
    func testWeightLookupIsUnchanged() throws {
        let c = try XCTUnwrap(WHOGrowthStandard.lms(ageDays: 0, isMale: true))
        XCTAssertEqual(c.l, 0.3487, accuracy: 1e-9)
        XCTAssertEqual(c.m, 3.3464, accuracy: 1e-9)
        XCTAssertEqual(c.s, 0.14602, accuracy: 1e-9)
    }
}
