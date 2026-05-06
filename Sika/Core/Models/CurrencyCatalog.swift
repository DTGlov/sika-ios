import Foundation

enum CurrencyCatalog {
    /// Currency codes that should appear at the top of pickers, in this order.
    /// Matches web's POPULAR_CURRENCIES.
    static let popularCodes: [String] = [
        "GHS", "NGN", "KES", "ZAR", "EGP", "USD", "EUR", "GBP",
    ]

    /// All supported currencies. Matches web's ALL_CURRENCIES (TWD deduped).
    /// Africa-first ordering preserved.
    static let all: [Currency] = [
        Currency(code: "GHS", name: "Ghana Cedi", symbol: "₵"),
        Currency(code: "NGN", name: "Nigerian Naira", symbol: "₦"),
        Currency(code: "KES", name: "Kenyan Shilling", symbol: "KSh"),
        Currency(code: "ZAR", name: "South African Rand", symbol: "R"),
        Currency(code: "EGP", name: "Egyptian Pound", symbol: "E£"),
        Currency(code: "ETB", name: "Ethiopian Birr", symbol: "Br"),
        Currency(code: "TZS", name: "Tanzanian Shilling", symbol: "TSh"),
        Currency(code: "UGX", name: "Ugandan Shilling", symbol: "USh"),
        Currency(code: "XOF", name: "West African CFA Franc", symbol: "CFA"),
        Currency(code: "XAF", name: "Central African CFA Franc", symbol: "FCFA"),
        Currency(code: "MAD", name: "Moroccan Dirham", symbol: "MAD"),
        Currency(code: "DZD", name: "Algerian Dinar", symbol: "DA"),
        Currency(code: "TND", name: "Tunisian Dinar", symbol: "DT"),
        Currency(code: "ZMW", name: "Zambian Kwacha", symbol: "ZK"),
        Currency(code: "MWK", name: "Malawian Kwacha", symbol: "MK"),
        Currency(code: "RWF", name: "Rwandan Franc", symbol: "RF"),
        Currency(code: "BIF", name: "Burundian Franc", symbol: "FBu"),
        Currency(code: "DJF", name: "Djiboutian Franc", symbol: "Fdj"),
        Currency(code: "ERN", name: "Eritrean Nakfa", symbol: "Nfk"),
        Currency(code: "SOS", name: "Somali Shilling", symbol: "Sh"),
        Currency(code: "SDG", name: "Sudanese Pound", symbol: "SDG"),
        Currency(code: "LYD", name: "Libyan Dinar", symbol: "LD"),
        Currency(code: "MZN", name: "Mozambican Metical", symbol: "MT"),
        Currency(code: "AOA", name: "Angolan Kwanza", symbol: "Kz"),
        Currency(code: "CDF", name: "Congolese Franc", symbol: "FC"),
        Currency(code: "GMD", name: "Gambian Dalasi", symbol: "D"),
        Currency(code: "GNF", name: "Guinean Franc", symbol: "FG"),
        Currency(code: "SLL", name: "Sierra Leonean Leone", symbol: "Le"),
        Currency(code: "LRD", name: "Liberian Dollar", symbol: "L$"),
        Currency(code: "CVE", name: "Cape Verdean Escudo", symbol: "CV$"),
        Currency(code: "STN", name: "São Tomé Príncipe Dobra", symbol: "Db"),
        Currency(code: "KMF", name: "Comorian Franc", symbol: "CF"),
        Currency(code: "MGA", name: "Malagasy Ariary", symbol: "Ar"),
        Currency(code: "MUR", name: "Mauritian Rupee", symbol: "₨"),
        Currency(code: "SCR", name: "Seychellois Rupee", symbol: "₨"),
        Currency(code: "BWP", name: "Botswana Pula", symbol: "P"),
        Currency(code: "NAD", name: "Namibian Dollar", symbol: "N$"),
        Currency(code: "SZL", name: "Swazi Lilangeni", symbol: "L"),
        Currency(code: "LSL", name: "Lesotho Loti", symbol: "L"),
        Currency(code: "USD", name: "US Dollar", symbol: "$"),
        Currency(code: "EUR", name: "Euro", symbol: "€"),
        Currency(code: "GBP", name: "British Pound", symbol: "£"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        Currency(code: "INR", name: "Indian Rupee", symbol: "₹"),
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "CA$"),
        Currency(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        Currency(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        Currency(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        Currency(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        Currency(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$"),
        Currency(code: "SEK", name: "Swedish Krona", symbol: "kr"),
        Currency(code: "NOK", name: "Norwegian Krone", symbol: "kr"),
        Currency(code: "DKK", name: "Danish Krone", symbol: "kr"),
        Currency(code: "MXN", name: "Mexican Peso", symbol: "$"),
        Currency(code: "BRL", name: "Brazilian Real", symbol: "R$"),
        Currency(code: "ARS", name: "Argentine Peso", symbol: "$"),
        Currency(code: "CLP", name: "Chilean Peso", symbol: "$"),
        Currency(code: "COP", name: "Colombian Peso", symbol: "$"),
        Currency(code: "PEN", name: "Peruvian Sol", symbol: "S/"),
        Currency(code: "VES", name: "Venezuelan Bolívar", symbol: "Bs."),
        Currency(code: "KRW", name: "South Korean Won", symbol: "₩"),
        Currency(code: "TWD", name: "New Taiwan Dollar", symbol: "NT$"),
        Currency(code: "IDR", name: "Indonesian Rupiah", symbol: "Rp"),
        Currency(code: "MYR", name: "Malaysian Ringgit", symbol: "RM"),
        Currency(code: "THB", name: "Thai Baht", symbol: "฿"),
        Currency(code: "PHP", name: "Philippine Peso", symbol: "₱"),
        Currency(code: "VND", name: "Vietnamese Dong", symbol: "₫"),
        Currency(code: "PKR", name: "Pakistani Rupee", symbol: "₨"),
        Currency(code: "BDT", name: "Bangladeshi Taka", symbol: "৳"),
        Currency(code: "LKR", name: "Sri Lankan Rupee", symbol: "Rs"),
        Currency(code: "NPR", name: "Nepalese Rupee", symbol: "Rs"),
        Currency(code: "AED", name: "UAE Dirham", symbol: "د.إ"),
        Currency(code: "SAR", name: "Saudi Riyal", symbol: "﷼"),
        Currency(code: "QAR", name: "Qatari Riyal", symbol: "﷼"),
        Currency(code: "KWD", name: "Kuwaiti Dinar", symbol: "KD"),
        Currency(code: "BHD", name: "Bahraini Dinar", symbol: "BD"),
        Currency(code: "OMR", name: "Omani Rial", symbol: "OMR"),
        Currency(code: "JOD", name: "Jordanian Dinar", symbol: "JD"),
        Currency(code: "ILS", name: "Israeli Shekel", symbol: "₪"),
        Currency(code: "TRY", name: "Turkish Lira", symbol: "₺"),
        Currency(code: "RUB", name: "Russian Ruble", symbol: "₽"),
        Currency(code: "PLN", name: "Polish Zloty", symbol: "zł"),
        Currency(code: "CZK", name: "Czech Koruna", symbol: "Kč"),
        Currency(code: "HUF", name: "Hungarian Forint", symbol: "Ft"),
        Currency(code: "RON", name: "Romanian Leu", symbol: "lei"),
        Currency(code: "BGN", name: "Bulgarian Lev", symbol: "лв"),
        Currency(code: "HRK", name: "Croatian Kuna", symbol: "kn"),
        Currency(code: "ISK", name: "Icelandic Króna", symbol: "kr"),
        Currency(code: "UAH", name: "Ukrainian Hryvnia", symbol: "₴"),
        Currency(code: "GEL", name: "Georgian Lari", symbol: "₾"),
        Currency(code: "AMD", name: "Armenian Dram", symbol: "֏"),
        Currency(code: "AZN", name: "Azerbaijani Manat", symbol: "₼"),
        Currency(code: "KZT", name: "Kazakhstani Tenge", symbol: "₸"),
        Currency(code: "UZS", name: "Uzbekistani Som", symbol: "so'm"),
        Currency(code: "MNT", name: "Mongolian Tögrög", symbol: "₮"),
        Currency(code: "MMK", name: "Myanmar Kyat", symbol: "K"),
        Currency(code: "KHR", name: "Cambodian Riel", symbol: "៛"),
        Currency(code: "LAK", name: "Lao Kip", symbol: "₭"),
        Currency(code: "BND", name: "Brunei Dollar", symbol: "B$"),
        Currency(code: "PGK", name: "Papua New Guinean Kina", symbol: "K"),
        Currency(code: "FJD", name: "Fijian Dollar", symbol: "FJ$"),
        Currency(code: "WST", name: "Samoan Tala", symbol: "WS$"),
        Currency(code: "TOP", name: "Tongan Paʻanga", symbol: "T$"),
        Currency(code: "SBD", name: "Solomon Islands Dollar", symbol: "SI$"),
        Currency(code: "VUV", name: "Vanuatu Vatu", symbol: "VT"),
        Currency(code: "GTQ", name: "Guatemalan Quetzal", symbol: "Q"),
        Currency(code: "HNL", name: "Honduran Lempira", symbol: "L"),
        Currency(code: "NIO", name: "Nicaraguan Córdoba", symbol: "C$"),
        Currency(code: "CRC", name: "Costa Rican Colón", symbol: "₡"),
        Currency(code: "PAB", name: "Panamanian Balboa", symbol: "B/."),
        Currency(code: "DOP", name: "Dominican Peso", symbol: "RD$"),
        Currency(code: "HTG", name: "Haitian Gourde", symbol: "G"),
        Currency(code: "JMD", name: "Jamaican Dollar", symbol: "J$"),
        Currency(code: "TTD", name: "Trinidad & Tobago Dollar", symbol: "TT$"),
        Currency(code: "BBD", name: "Barbadian Dollar", symbol: "Bds$"),
        Currency(code: "GYD", name: "Guyanese Dollar", symbol: "G$"),
        Currency(code: "SRD", name: "Surinamese Dollar", symbol: "$"),
        Currency(code: "BOB", name: "Bolivian Boliviano", symbol: "Bs."),
        Currency(code: "PYG", name: "Paraguayan Guaraní", symbol: "₲"),
        Currency(code: "UYU", name: "Uruguayan Peso", symbol: "$U"),
        Currency(code: "IRR", name: "Iranian Rial", symbol: "﷼"),
        Currency(code: "IQD", name: "Iraqi Dinar", symbol: "IQD"),
        Currency(code: "SYP", name: "Syrian Pound", symbol: "£"),
        Currency(code: "YER", name: "Yemeni Rial", symbol: "﷼"),
        Currency(code: "AFN", name: "Afghan Afghani", symbol: "؋"),
        Currency(code: "MVR", name: "Maldivian Rufiyaa", symbol: "Rf"),
        Currency(code: "BTN", name: "Bhutanese Ngultrum", symbol: "Nu"),
    ]

    /// Returns currencies in display order: popular first, rest after.
    /// If `query` is non-empty, returns matching currencies (no popular reordering).
    static func filtered(by query: String) -> [Currency] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty {
            let popular = popularCodes.compactMap { code in all.first { $0.code == code } }
            let rest = all.filter { !popularCodes.contains($0.code) }
            return popular + rest
        }
        return all.filter { c in
            c.code.lowercased().contains(trimmed)
                || c.name.lowercased().contains(trimmed)
                || c.symbol.lowercased().contains(trimmed)
        }
    }

    static func currency(forCode code: String) -> Currency? {
        all.first { $0.code == code }
    }
}
