import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case automatic
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var localizedTitleKey: String {
        switch self {
        case .automatic: "language.automatic"
        case .simplifiedChinese: "language.zhHans"
        case .english: "language.english"
        }
    }

    var locale: Locale? {
        switch self {
        case .automatic: nil
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }
}
