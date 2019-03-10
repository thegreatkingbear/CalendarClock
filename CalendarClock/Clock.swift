//
//  Clock.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-02-18.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation

class Clock {
    
    // MARK: - Properties
    static let dateFormatter = DateFormatter()
    static var flick: Bool = false

    static func currentDateString() -> String {
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let second = Calendar.current.component(.second, from: Date())
        var now = ""
        if flick {
            flick = false
            now = "\(hour):\(minute)"
        } else {
            flick = true
            now = "\(hour) \(minute)"
        }
//        return dateFormatter.string(from: Date())
        return now
    }
}
