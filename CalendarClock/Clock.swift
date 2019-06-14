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
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        //let second = Calendar.current.component(.second, from: Date())
        var now = ""
        if flick {
            flick = false
            now = String(format:"%02d", hour) + ":" + String(format:"%02d", minute)
        } else {
            flick = true
            now = String(format:"%02d", hour) + " " + String(format:"%02d", minute)
        }
        
        return now
    }
    
    static func currentDayString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = NSTimeZone.local
        dateFormatter.dateFormat = "EEEE, MMMM d" // 금요일, 6월 14 or Friday, June 14
        return dateFormatter.string(from: Date())
    }
}
