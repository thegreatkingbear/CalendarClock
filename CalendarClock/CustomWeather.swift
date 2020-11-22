//
//  CustomWeather.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2020/11/22.
//  Copyright © 2020 Mookyung Kwak. All rights reserved.
//

import Foundation

struct FutureCondition: Codable {
    var list: [Condition]
}

struct Condition: Codable, Equatable {
    var main: ConditionMain
    var weather: [ConditionWeather]
    var dt: Int
    
    static func ==(lhs: Condition, rhs: Condition) -> Bool {
        return lhs.main.temp == rhs.main.temp && lhs.dt == rhs.dt && lhs.weather[0].id == rhs.weather[0].id
    }

    // convert dt to day string
    func day() -> Int {
        let date = Date(timeIntervalSince1970: Double(dt))
        let day = Calendar.current.component(.day, from: date)
        return day
    }
    
    func weekday() -> String {
        let date = Date(timeIntervalSince1970: Double(dt))
        
        // I just used this here instead of Apple's weekday property.
        // It works well with user's locale
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    // convert dt to hour string
    func hour() -> String {
        let date = Date(timeIntervalSince1970: Double(dt))
        let hour = Calendar.current.component(.hour, from: date)
        return String(format:"%02d", hour)
    }

}

struct ConditionMain: Codable {
    var humidity: Int
    var temp: Double
    var feels_like: Double
}

struct ConditionWeather: Codable {
    var description: String
    var id: Int
    var icon: String
}
