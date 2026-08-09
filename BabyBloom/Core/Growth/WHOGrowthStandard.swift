import Foundation

/// WHO Child Growth Standards 2006 — weight-for-age, birth to 24 months.
///
/// Source: World Health Organization, "WHO Child Growth Standards: weight-for-age",
/// expanded z-score tables (LMS coefficients):
/// https://www.who.int/tools/child-growth-standards/standards/weight-for-age
///
/// Percentiles come from the published LMS coefficients rather than a normal
/// approximation. That matters because `l` is nowhere near 1 in infancy — the
/// weight distribution is genuinely skewed — and the approximation drifts worst
/// in the tails, which is exactly where a worried parent's reading tends to land.
///
/// WHO publishes a row for every day. Keeping all 731 would be mostly redundant,
/// so this table stores a subset and interpolates `l`, `m`, `s` linearly between
/// neighbours: every day for the first month, weekly to 13 weeks, fortnightly to
/// 24 months. The grid was picked by measuring against the full daily table —
/// worst-case error is 0.008 z anywhere in −3…+3, invisible once rounded to a
/// percentile. A plain weekly grid was tried first and rejected: it degraded to
/// 0.14 z around day 2, where `l` and `m` move fastest and where the newborn
/// screen needs them most.
///
/// Every entry point takes an age in days and expects the **corrected** age for
/// a baby born preterm (see `Baby.correctedAgeDays`).
enum WHOGrowthStandard {

    /// The three coefficients of the LMS method: Box-Cox power, median, and
    /// coefficient of variation.
    struct LMS {
        let l: Double
        let m: Double
        let s: Double
    }

    private struct Node {
        let day: Int
        let l: Double
        let m: Double
        let s: Double
    }

    /// Oldest age the tables cover. Past this every entry point returns `nil`
    /// rather than reusing the last row: a three-year-old measured against a
    /// two-year-old reference is a wrong answer, not an approximate one.
    static let maxAgeDays = 730

    // MARK: - Lookup

    /// Interpolated coefficients for an age, or `nil` outside the covered range.
    static func lms(ageDays: Int, isMale: Bool) -> LMS? {
        guard ageDays >= 0, ageDays <= maxAgeDays else { return nil }
        let table = isMale ? boys : girls

        // Exact node, or the pair straddling this age.
        var lower = table[0]
        for node in table {
            if node.day == ageDays {
                return LMS(l: node.l, m: node.m, s: node.s)
            }
            if node.day < ageDays {
                lower = node
            } else {
                let span = Double(node.day - lower.day)
                let t = span > 0 ? Double(ageDays - lower.day) / span : 0
                return LMS(
                    l: lower.l + (node.l - lower.l) * t,
                    m: lower.m + (node.m - lower.m) * t,
                    s: lower.s + (node.s - lower.s) * t
                )
            }
        }
        return LMS(l: lower.l, m: lower.m, s: lower.s)
    }

    /// Standard deviations from the median for this weight, or `nil` if the age
    /// is outside the tables or the weight is not a positive number.
    static func zScore(weightKg: Double, ageDays: Int, isMale: Bool) -> Double? {
        guard weightKg > 0, let c = lms(ageDays: ageDays, isMale: isMale), c.m > 0, c.s > 0 else {
            return nil
        }
        if abs(c.l) < 1e-9 {
            return log(weightKg / c.m) / c.s
        }
        return (pow(weightKg / c.m, c.l) - 1) / (c.l * c.s)
    }

    /// Weight percentile, rounded and clamped to the 1–99 range shown to users.
    static func percentile(weightKg: Double, ageDays: Int, isMale: Bool) -> Double? {
        guard let z = zScore(weightKg: weightKg, ageDays: ageDays, isMale: isMale) else { return nil }
        return percentile(fromZ: z)
    }

    /// Normal CDF, expressed as a 1–99 percentile.
    static func percentile(fromZ z: Double) -> Double {
        let p = 0.5 * (1 + erf(z / 2.0.squareRoot()))
        return max(1, min(99, (p * 100).rounded()))
    }

    // MARK: - Presentation

    /// Localized percentile band label. Bands share identical boundaries with
    /// `percentileColor`: 3 / 15 / 50 / 85 / 97 (upper-inclusive within a band).
    static func percentileLabel(_ percentile: Double) -> String {
        switch percentile {
        case ..<3:  return "percentile.below3".l
        case ...15: return "percentile.3_15".l
        case ...50: return "percentile.15_50".l
        case ...85: return "percentile.50_85".l
        case ...97: return "percentile.85_97".l
        default:    return "percentile.above97".l
        }
    }

    /// Band color. Boundaries are identical to `percentileLabel` (3 / 15 / 50 / 85 / 97):
    /// green in the healthy 15–85 range, orange at the edges, red beyond 3 / 97.
    static func percentileColor(_ percentile: Double) -> String {
        switch percentile {
        case ..<3:  return "#E05A5A"
        case ...15: return "#F5A45F"
        case ...50: return "#6BBF6B"
        case ...85: return "#6BBF6B"
        case ...97: return "#F5A45F"
        default:    return "#E05A5A"
        }
    }

    // MARK: - WHO tables (transcribed, do not hand-edit)

    private static let boys: [Node] = [
        Node(day: 0, l: 0.3487, m: 3.3464, s: 0.14602),
        Node(day: 1, l: 0.3127, m: 3.3174, s: 0.14693),
        Node(day: 2, l: 0.3029, m: 3.337, s: 0.14676),
        Node(day: 3, l: 0.2959, m: 3.3627, s: 0.14647),
        Node(day: 4, l: 0.2903, m: 3.3915, s: 0.14611),
        Node(day: 5, l: 0.2855, m: 3.4223, s: 0.14571),
        Node(day: 6, l: 0.2813, m: 3.4545, s: 0.14528),
        Node(day: 7, l: 0.2776, m: 3.4879, s: 0.14483),
        Node(day: 8, l: 0.2742, m: 3.5222, s: 0.14436),
        Node(day: 9, l: 0.2711, m: 3.5576, s: 0.14388),
        Node(day: 10, l: 0.2681, m: 3.5941, s: 0.14339),
        Node(day: 11, l: 0.2654, m: 3.6319, s: 0.1429),
        Node(day: 12, l: 0.2628, m: 3.671, s: 0.14241),
        Node(day: 13, l: 0.2604, m: 3.7113, s: 0.14192),
        Node(day: 14, l: 0.2581, m: 3.7529, s: 0.14142),
        Node(day: 15, l: 0.2558, m: 3.7956, s: 0.14093),
        Node(day: 16, l: 0.2537, m: 3.8389, s: 0.14044),
        Node(day: 17, l: 0.2517, m: 3.8828, s: 0.13996),
        Node(day: 18, l: 0.2497, m: 3.927, s: 0.13948),
        Node(day: 19, l: 0.2478, m: 3.9714, s: 0.139),
        Node(day: 20, l: 0.246, m: 4.0158, s: 0.13853),
        Node(day: 21, l: 0.2442, m: 4.0603, s: 0.13807),
        Node(day: 22, l: 0.2425, m: 4.1046, s: 0.13761),
        Node(day: 23, l: 0.2408, m: 4.1489, s: 0.13715),
        Node(day: 24, l: 0.2392, m: 4.193, s: 0.1367),
        Node(day: 25, l: 0.2376, m: 4.2369, s: 0.13626),
        Node(day: 26, l: 0.2361, m: 4.2806, s: 0.13582),
        Node(day: 27, l: 0.2346, m: 4.324, s: 0.13539),
        Node(day: 28, l: 0.2331, m: 4.3671, s: 0.13497),
        Node(day: 29, l: 0.2317, m: 4.41, s: 0.13455),
        Node(day: 30, l: 0.2303, m: 4.4525, s: 0.13413),
        Node(day: 35, l: 0.2237, m: 4.659, s: 0.13215),
        Node(day: 42, l: 0.2155, m: 4.9303, s: 0.1296),
        Node(day: 49, l: 0.2081, m: 5.1817, s: 0.12729),
        Node(day: 56, l: 0.2014, m: 5.4149, s: 0.1252),
        Node(day: 63, l: 0.1952, m: 5.6319, s: 0.1233),
        Node(day: 70, l: 0.1894, m: 5.8346, s: 0.12157),
        Node(day: 77, l: 0.184, m: 6.0242, s: 0.12001),
        Node(day: 84, l: 0.1789, m: 6.2019, s: 0.1186),
        Node(day: 91, l: 0.174, m: 6.369, s: 0.11732),
        Node(day: 106, l: 0.1644, m: 6.6962, s: 0.11502),
        Node(day: 122, l: 0.1551, m: 7.0069, s: 0.11313),
        Node(day: 137, l: 0.1471, m: 7.2692, s: 0.1118),
        Node(day: 152, l: 0.1396, m: 7.5077, s: 0.11081),
        Node(day: 167, l: 0.1326, m: 7.7255, s: 0.11009),
        Node(day: 182, l: 0.126, m: 7.926, s: 0.10959),
        Node(day: 198, l: 0.1193, m: 8.1239, s: 0.10924),
        Node(day: 213, l: 0.1134, m: 8.2963, s: 0.10902),
        Node(day: 228, l: 0.1077, m: 8.4578, s: 0.10889),
        Node(day: 243, l: 0.1023, m: 8.6102, s: 0.10882),
        Node(day: 258, l: 0.097, m: 8.7548, s: 0.1088),
        Node(day: 274, l: 0.0917, m: 8.9019, s: 0.10881),
        Node(day: 289, l: 0.0868, m: 9.0342, s: 0.10885),
        Node(day: 304, l: 0.0821, m: 9.1618, s: 0.1089),
        Node(day: 319, l: 0.0776, m: 9.2854, s: 0.10897),
        Node(day: 334, l: 0.0732, m: 9.4057, s: 0.10905),
        Node(day: 350, l: 0.0686, m: 9.531, s: 0.10915),
        Node(day: 365, l: 0.0645, m: 9.646, s: 0.10925),
        Node(day: 380, l: 0.0605, m: 9.7588, s: 0.10936),
        Node(day: 395, l: 0.0565, m: 9.8699, s: 0.10948),
        Node(day: 410, l: 0.0527, m: 9.9792, s: 0.10961),
        Node(day: 426, l: 0.0487, m: 10.0944, s: 0.10976),
        Node(day: 441, l: 0.045, m: 10.2011, s: 0.10991),
        Node(day: 456, l: 0.0414, m: 10.3069, s: 0.11007),
        Node(day: 471, l: 0.0379, m: 10.4118, s: 0.11023),
        Node(day: 486, l: 0.0345, m: 10.5159, s: 0.1104),
        Node(day: 502, l: 0.0309, m: 10.6262, s: 0.11059),
        Node(day: 517, l: 0.0276, m: 10.7289, s: 0.11078),
        Node(day: 532, l: 0.0244, m: 10.831, s: 0.11098),
        Node(day: 547, l: 0.0212, m: 10.9326, s: 0.11118),
        Node(day: 562, l: 0.0181, m: 11.0336, s: 0.11139),
        Node(day: 578, l: 0.0149, m: 11.1409, s: 0.11163),
        Node(day: 593, l: 0.0118, m: 11.2411, s: 0.11186),
        Node(day: 608, l: 0.0089, m: 11.3412, s: 0.1121),
        Node(day: 623, l: 0.006, m: 11.441, s: 0.11234),
        Node(day: 638, l: 0.0031, m: 11.5407, s: 0.11259),
        Node(day: 654, l: 0.0001, m: 11.6469, s: 0.11287),
        Node(day: 669, l: -0.0027, m: 11.7462, s: 0.11313),
        Node(day: 684, l: -0.0054, m: 11.8454, s: 0.1134),
        Node(day: 699, l: -0.0081, m: 11.9444, s: 0.11367),
        Node(day: 714, l: -0.0108, m: 12.0431, s: 0.11395),
        Node(day: 730, l: -0.0136, m: 12.1482, s: 0.11425),
    ]

    private static let girls: [Node] = [
        Node(day: 0, l: 0.3809, m: 3.2322, s: 0.14171),
        Node(day: 1, l: 0.3259, m: 3.1957, s: 0.14578),
        Node(day: 2, l: 0.3101, m: 3.2104, s: 0.14637),
        Node(day: 3, l: 0.2986, m: 3.2315, s: 0.14657),
        Node(day: 4, l: 0.2891, m: 3.2558, s: 0.14658),
        Node(day: 5, l: 0.281, m: 3.2821, s: 0.14646),
        Node(day: 6, l: 0.2737, m: 3.3099, s: 0.14626),
        Node(day: 7, l: 0.2671, m: 3.3388, s: 0.146),
        Node(day: 8, l: 0.2609, m: 3.3687, s: 0.14569),
        Node(day: 9, l: 0.2551, m: 3.3995, s: 0.14534),
        Node(day: 10, l: 0.2497, m: 3.4314, s: 0.14498),
        Node(day: 11, l: 0.2446, m: 3.4643, s: 0.14459),
        Node(day: 12, l: 0.2397, m: 3.4983, s: 0.1442),
        Node(day: 13, l: 0.2349, m: 3.5333, s: 0.1438),
        Node(day: 14, l: 0.2304, m: 3.5693, s: 0.14339),
        Node(day: 15, l: 0.226, m: 3.6063, s: 0.14299),
        Node(day: 16, l: 0.2218, m: 3.6438, s: 0.14258),
        Node(day: 17, l: 0.2177, m: 3.6818, s: 0.14218),
        Node(day: 18, l: 0.2137, m: 3.7201, s: 0.14177),
        Node(day: 19, l: 0.2099, m: 3.7584, s: 0.14138),
        Node(day: 20, l: 0.2061, m: 3.7968, s: 0.14098),
        Node(day: 21, l: 0.2024, m: 3.8352, s: 0.1406),
        Node(day: 22, l: 0.1989, m: 3.8735, s: 0.14021),
        Node(day: 23, l: 0.1954, m: 3.9116, s: 0.13984),
        Node(day: 24, l: 0.1919, m: 3.9495, s: 0.13947),
        Node(day: 25, l: 0.1886, m: 3.9872, s: 0.1391),
        Node(day: 26, l: 0.1853, m: 4.0247, s: 0.13875),
        Node(day: 27, l: 0.1821, m: 4.0618, s: 0.1384),
        Node(day: 28, l: 0.1789, m: 4.0987, s: 0.13805),
        Node(day: 29, l: 0.1758, m: 4.1353, s: 0.13771),
        Node(day: 30, l: 0.1727, m: 4.1716, s: 0.13738),
        Node(day: 35, l: 0.1582, m: 4.3476, s: 0.13583),
        Node(day: 42, l: 0.1395, m: 4.5793, s: 0.13392),
        Node(day: 49, l: 0.1224, m: 4.795, s: 0.13228),
        Node(day: 56, l: 0.1065, m: 4.9959, s: 0.13087),
        Node(day: 63, l: 0.0918, m: 5.1842, s: 0.12966),
        Node(day: 70, l: 0.0779, m: 5.3618, s: 0.12861),
        Node(day: 77, l: 0.0648, m: 5.5295, s: 0.1277),
        Node(day: 84, l: 0.0525, m: 5.6883, s: 0.12691),
        Node(day: 91, l: 0.0407, m: 5.8393, s: 0.12622),
        Node(day: 106, l: 0.0173, m: 6.1393, s: 0.125),
        Node(day: 122, l: -0.0053, m: 6.428, s: 0.12401),
        Node(day: 137, l: -0.0248, m: 6.6729, s: 0.12329),
        Node(day: 152, l: -0.0428, m: 6.8959, s: 0.12274),
        Node(day: 167, l: -0.0594, m: 7.1003, s: 0.12234),
        Node(day: 182, l: -0.0749, m: 7.2894, s: 0.12205),
        Node(day: 198, l: -0.0904, m: 7.477, s: 0.12187),
        Node(day: 213, l: -0.1039, m: 7.6416, s: 0.12178),
        Node(day: 228, l: -0.1165, m: 7.7968, s: 0.12177),
        Node(day: 243, l: -0.1284, m: 7.9439, s: 0.1218),
        Node(day: 258, l: -0.1396, m: 8.0837, s: 0.12188),
        Node(day: 274, l: -0.1507, m: 8.2259, s: 0.12199),
        Node(day: 289, l: -0.1606, m: 8.3536, s: 0.1221),
        Node(day: 304, l: -0.1698, m: 8.4769, s: 0.12222),
        Node(day: 319, l: -0.1785, m: 8.5965, s: 0.12235),
        Node(day: 334, l: -0.1867, m: 8.713, s: 0.12246),
        Node(day: 350, l: -0.195, m: 8.8344, s: 0.12258),
        Node(day: 365, l: -0.2022, m: 8.9462, s: 0.12267),
        Node(day: 380, l: -0.2091, m: 9.0563, s: 0.12276),
        Node(day: 395, l: -0.2155, m: 9.165, s: 0.12283),
        Node(day: 410, l: -0.2216, m: 9.2725, s: 0.12289),
        Node(day: 426, l: -0.2277, m: 9.3861, s: 0.12294),
        Node(day: 441, l: -0.2331, m: 9.4918, s: 0.12297),
        Node(day: 456, l: -0.2382, m: 9.5968, s: 0.12299),
        Node(day: 471, l: -0.243, m: 9.7013, s: 0.12301),
        Node(day: 486, l: -0.2475, m: 9.8054, s: 0.12303),
        Node(day: 502, l: -0.2521, m: 9.9161, s: 0.12304),
        Node(day: 517, l: -0.2561, m: 10.0196, s: 0.12305),
        Node(day: 532, l: -0.2599, m: 10.1227, s: 0.12307),
        Node(day: 547, l: -0.2635, m: 10.2255, s: 0.12309),
        Node(day: 562, l: -0.2669, m: 10.3281, s: 0.12312),
        Node(day: 578, l: -0.2702, m: 10.4372, s: 0.12315),
        Node(day: 593, l: -0.2732, m: 10.5393, s: 0.12319),
        Node(day: 608, l: -0.2761, m: 10.6413, s: 0.12323),
        Node(day: 623, l: -0.2787, m: 10.7433, s: 0.12328),
        Node(day: 638, l: -0.2813, m: 10.8453, s: 0.12335),
        Node(day: 654, l: -0.2838, m: 10.9542, s: 0.12342),
        Node(day: 669, l: -0.2861, m: 11.0565, s: 0.1235),
        Node(day: 684, l: -0.2882, m: 11.1589, s: 0.12359),
        Node(day: 699, l: -0.2902, m: 11.2616, s: 0.12368),
        Node(day: 714, l: -0.2921, m: 11.3643, s: 0.12378),
        Node(day: 730, l: -0.294, m: 11.4741, s: 0.12389),
    ]
}
