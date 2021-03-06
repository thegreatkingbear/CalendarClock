//
//  Event.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-02-18.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation
import EventKit
import RxSwift
import RxDataSources

class CalendarEvent {
    
    // Variables to be globally watched
    var authorized = BehaviorSubject<Bool>(value: false)
    var selectedCalendars = BehaviorSubject<[String]>(value: [])
    
    var store = EKEventStore()
    
    // Singleton
    private static var sharedEvent: CalendarEvent = {
        let event = CalendarEvent()
        
        return event
    }()
    
    class func shared() -> CalendarEvent {
        return sharedEvent
    }
    
    // Initialization
    private init() {
        
    }
    
    func verifyAuthorityToEvents() {
        
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)

        switch (status) {
        case .notDetermined:
            requestAccessToEvents()
            break
        case .authorized:
            authorized.onNext(true)
            break
        case .restricted, .denied:
            authorized.onNext(false)
            authorized.onCompleted()
            break
        }
    }
    
    func requestAccessToEvents() {
        store.requestAccess(to: EKEntityType.event) { (accessGranted, error) in
            if accessGranted {
                self.store = EKEventStore() // without reallocating event store here, it makes error fetching event data in the first run
                self.authorized.onNext(true)
            } else if error != nil {
                self.authorized.onError(error!)
            } else {
                self.authorized.onNext(true)
            }
            self.authorized.onCompleted()
        }
    }
    
    func fetchCalendars() -> Observable<[CalendarSetting]> {
        return Observable.create({ (observer) -> Disposable in
            let calendars = CalendarEvent.shared().store.calendars(for: .event)
            
            var retCalendars = [CalendarSetting]()
            for calendar in calendars {
                retCalendars
                    .append(
                        CalendarSetting(
                            owner: calendar.source.title,
                            name: calendar.title,
                            identifier: calendar.calendarIdentifier,
                            isSelected: true))
            }
            
            observer.onNext(retCalendars)
            observer.onCompleted()
            
            return Disposables.create()
        })
        
    }
    
    func saveToUserDefaults(settings: [SectionedEventSettings]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "calendarSettings")
        }
    }
    
    func loadFromUserDefaults() -> Observable<[SectionedEventSettings]> {
        return Observable.create({ (observer) -> Disposable in
            if let loaded = UserDefaults.standard.object(forKey: "calendarSettings") as? Data {
                let decoder = JSONDecoder()
                if let decodedCalendars = try? decoder.decode([SectionedEventSettings].self, from: loaded) {
                    observer.onNext(decodedCalendars)
                    observer.onCompleted()
                } else {
                    observer.onNext([])
                    observer.onCompleted()
                }
            } else {
                observer.onNext([])
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }
    
    // I wanted to merge this method into mergeCalendars which is just below
    // But when I exchanged the caller in EventSettingViewReactor,
    // it fails to call the mergeCalendars method
    // Further investigation needed, but I think the reason is beneath the observable return value
    func collectSelectedCalendarIdentifiers(calendars: [SectionedEventSettings]) {
        var identifiers = [String]()
        for sectionedEventSetting in calendars {
            for item in sectionedEventSetting.items {
                if item.isSelected {
                    identifiers.append(item.identifier)
                }
            }
        }
        self.selectedCalendars.onNext(identifiers)
    }
    
    func mergeCalendars() -> Observable<[SectionedEventSettings]> {
        return Observable.combineLatest(
            fetchCalendars(),
            loadFromUserDefaults(),
            resultSelector: { fetched, loadedCalendars -> [SectionedEventSettings] in
                // reorganize fetched calendars into sectioned table view rows
                let sortedCalendars = fetched.sorted(by: { $0.owner < $1.owner })
                var groupedCalendars = sortedCalendars.reduce([SectionedEventSettings]()) {
                    guard var last = $0.last else { return [SectionedEventSettings(header: $1.owner, items: [$1])] }
                    var collection = $0
                    if last.header == $1.owner {
                        last.items += [$1]
                        collection[collection.count - 1] = last
                    } else {
                        collection += [SectionedEventSettings(header: $1.owner, items: [$1])]
                    }
                    return collection
                }
                
                // find same calendar item and populate them with previously saved value
                groupedCalendars = loadedCalendars + groupedCalendars.filter { !loadedCalendars.contains($0) }
                
                // collect selected calendars and push them
                var identifiers = [String]()
                for sectionedEventSetting in groupedCalendars {
                    for item in sectionedEventSetting.items {
                        if item.isSelected {
                            identifiers.append(item.identifier)
                        }
                    }
                }
                self.selectedCalendars.onNext(identifiers)
                return groupedCalendars
        })
    }
    
    func fetchEventsDetail() -> Observable<[CustomEvent]> {
        // call out every calendars
        let calendars = CalendarEvent.shared().store.calendars(for: .event)
        let selected = try! selectedCalendars.value()
        // filter calendars out of collected identifiers
        // Note: if we use calendarWithIdentifier method, we get weird error like
        // "Error getting shared calendar invitations for entity types 3 from
        // daemon: Error Domain=EKCADErrorDomain Code=1013"
        let filtered = calendars.filter { selected.contains($0.calendarIdentifier) }
        var retEvents = [CustomEvent]()

        // Get the current calendar with local time zone
        var currentCalendar = Calendar.current
        currentCalendar.timeZone = NSTimeZone.local

        // Get today's beginning & end
        let dateFrom = Date()
        let dateStart = currentCalendar.startOfDay(for: Date())
        let dateTo = currentCalendar.date(byAdding: .day, value: 1, to: dateStart)!

        // Note: Times are printed in UTC.
        // Depending on where you live it won't print 00:00:00
        // but it will work with UTC times which can be converted to local time
        
        for calendar in filtered {
            let predicate = store.predicateForEvents(withStart: dateFrom as Date, end: dateTo as Date, calendars: [calendar])
            let events = store.events(matching: predicate)
            
            for event in events {
                retEvents
                    .append(
                        CustomEvent(
                            id: event.eventIdentifier,
                            title: event.title,
                            startDate: event.startDate,
                            endDate: event.endDate)!)
            }
        }
        
        // sort events in start date ascending order
        retEvents = retEvents.sorted(by: { $0.startDate.compare($1.startDate) == .orderedAscending })
        return Observable.create({ (observer) -> Disposable in
            
            observer.onNext(retEvents)
            observer.onCompleted()
            
            return Disposables.create()
        })
    }

}

struct CustomEvent: Equatable, IdentifiableType {
    typealias Identity = String
    
    var title = ""
    var startDate = Date()
    var endDate = Date()
    var isVisible = true
    let id: String
    var timeStamp: Int = 0

    init?(id: String, title: String, startDate: Date, endDate: Date) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
    
    static func ==(lhs: CustomEvent, rhs: CustomEvent) -> Bool {
        return lhs.title == rhs.title && lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate
    }
    
    var identity: String {
        return id
    }
    
    // this method looks like belonging to view model property
    func period() -> String {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        var expression = "all day"
        if calendar.dateComponents([.minute], from: startDate, to: endDate).minute! < 1439 {
            let startHour = calendar.component(.hour, from: startDate)
            let startMinute = calendar.component(.minute, from: startDate)
            let endHour = calendar.component(.hour, from: endDate)
            let endMinute = calendar.component(.minute, from: endDate)
            expression =
                String(format: "%02d", startHour) + ":" +
                String(format: "%02d", startMinute) +
                " ~ " +
                String(format: "%02d", endHour) + ":" +
                String(format: "%02d", endMinute)
        }
        return expression
    }
    
    // to update event table every 1 second
    mutating func timeDiff() {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let remaining = Int(calendar.dateComponents([.second], from: Date(), to: endDate).second!)
        timeStamp = remaining
    }
    
    func progress() -> Double {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let remaining = Double(calendar.dateComponents([.second], from: Date(), to: endDate).second!)
        let duration = Double(calendar.dateComponents([.second], from: startDate, to: endDate).second!)
        return 1 - remaining / duration
    }
    
}

struct SectionedEvents: Equatable {
    var header: String
    var items: [Item]
    
    static func ==(lhs: SectionedEvents, rhs: SectionedEvents) -> Bool {
        return lhs.header == rhs.header && lhs.items == rhs.items
    }
}

extension SectionedEvents: SectionModelType {
    typealias Item = CustomEvent
    
    init(original: SectionedEvents, items: [Item]) {
        self = original
        self.items = items
    }
}

extension SectionedEvents: AnimatableSectionModelType {
    typealias Identity = String
    
    var identity: String {
        return header
    }
}

struct CalendarSetting: Equatable, Codable {
    var owner = ""
    var name = ""
    var identifier = ""
    var isSelected = true
    
    static func ==(lhs: CalendarSetting, rhs: CalendarSetting) -> Bool {
        return lhs.identifier == rhs.identifier // isSelected is deleted to make possible of '+' operand in 'Merge' method
    }
}

struct SectionedEventSettings: Equatable, Codable {
    var header: String // owner
    var items: [Item]
    
    static func ==(lhs: SectionedEventSettings, rhs: SectionedEventSettings) -> Bool {
        return lhs.header == rhs.header && lhs.items == rhs.items
    }
}

extension SectionedEventSettings: SectionModelType {
    typealias Item = CalendarSetting
    
    init(original: SectionedEventSettings, items: [Item]) {
        self = original
        self.items = items
    }
}
