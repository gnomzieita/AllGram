import Foundation

enum DateFormat: String {
    case yearMonthDay = "yyyy-MM-dd"
    case hhmm = "HH:mm"
    case MMMdd_at_hmm = "MMM dd 'at' h:mm a"
    case voice = "HH:mm, dd.MM.yyyy"
    
//    let formatter = DateFormatter()
//    formatter.locale = Locale(identifier: "en_US_POSIX")
//    formatter.dateFormat = "h:mm a 'on' MMMM dd, yyyy"
//    formatter.amSymbol = "AM"
//    formatter.pmSymbol = "PM"
}


enum Formatter {
    // MARK: Relative Date Formatter
    static private func relativeDateTimeFormatter(dateTimeStyle: RelativeDateTimeFormatter.DateTimeStyle? = nil,
                                                  unitsStyle: RelativeDateTimeFormatter.UnitsStyle? = nil,
                                                  formattingContext: RelativeDateTimeFormatter.Context?,
                                                  locale: Locale) -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        if let dateTimeStyle = dateTimeStyle {
            formatter.dateTimeStyle = dateTimeStyle
        }
        if let unitsStyle = unitsStyle {
            formatter.unitsStyle = unitsStyle
        }
        if let formattingContext = formattingContext {
            formatter.formattingContext = formattingContext
        }
        formatter.locale = locale
        return formatter
    }

    static func string(forRelativeDate relativeDate: Date?,
                       to otherDate: Date = Date(),
                       context: RelativeDateTimeFormatter.Context? = nil,
                       locale: Locale = .current) -> String? {
        guard let relativeDate = relativeDate else {
            return nil
        }

        return relativeDateTimeFormatter(dateTimeStyle: .named, unitsStyle: .full, formattingContext: context, locale: locale)
            .localizedString(for: relativeDate, relativeTo: otherDate)
    }

    // MARK: Date Formatter
    fileprivate static func dateFormatter(format: DateFormat? = nil,
                                      dateStyle: DateFormatter.Style? = nil,
                                      timeStyle: DateFormatter.Style? = nil,
                                      locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        if let format = format {
            formatter.dateFormat = format.rawValue
        }
        if let dateStyle = dateStyle {
            formatter.dateStyle = dateStyle
        }
        if let timeStyle = timeStyle {
            formatter.timeStyle = timeStyle
        }
        formatter.locale = locale
        return formatter
    }

    static func string(for date: Date, format: DateFormat, locale: Locale = .current) -> String {
        let formatter = dateFormatter(format: format, locale: locale)
        return formatter.string(from: date)
    }

    static func string(for date: Date, dateStyle: DateFormatter.Style, locale: Locale = .current) -> String {
        string(for: date, dateStyle: dateStyle, timeStyle: .none, locale: locale)
    }

    static func string(for date: Date, timeStyle: DateFormatter.Style, locale: Locale = .current) -> String {
        string(for: date, dateStyle: .none, timeStyle: timeStyle, locale: locale)
    }

    static func string(for date: Date,
                       dateStyle: DateFormatter.Style,
                       timeStyle: DateFormatter.Style,
                       locale: Locale = .current) -> String {
        let formatter = dateFormatter(dateStyle: dateStyle, timeStyle: timeStyle, locale: locale)
        return formatter.string(from: date)
    }
    
    //MARK: - String Formatter
    static func usernameFromString(_ body: String) -> String {
        guard let sobakaIndex = body.firstIndex(of: "@") else { return body }
        guard let colonIndex = body.firstIndex(of: ":") else { return body }
        let username = body[sobakaIndex..<colonIndex].dropFirst()
        return String(username)
    }
    
    static func extractMessagesFromString(_ body: String) -> (String, String)? {
        let stringWOFirst = body.dropFirst()
        guard let firstIndexOfGT = stringWOFirst.firstIndex(of: ">") else { return nil }
        guard let newLineSymbol = stringWOFirst.firstIndex(of: "\n") else { return nil }
        
        let quoteMessage = String(body[firstIndexOfGT..<newLineSymbol].dropFirst())
        let message = String(body[newLineSymbol...])
        
        return (quoteMessage, message)
    }
}

extension Date{
    func string(format: DateFormat, locale: Locale = .current) -> String {
        let formatter = Formatter.dateFormatter(format: format, locale: locale)
        return formatter.string(from: self)
    }
}
