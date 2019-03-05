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

    static func currentDateString() -> String {
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: Date())
    }
}
