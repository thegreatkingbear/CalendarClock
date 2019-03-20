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

class EventStore: EKEventStore {
    
    // MARK: - Variables
    var authorized = BehaviorSubject<Bool>(value: false)
    
    // Initialization
    override init() {
        super.init()
        
        print("init event store")
        
    }
    
    func verifyAuthorityToEvents() {
        
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)

        switch (status) {
        case .notDetermined:
            requestAccessToEvents()
            break
        case .authorized:
            print("already authorized(event)")
            authorized.onNext(true)
            break
        case .restricted, .denied:
            authorized.onNext(false)
            authorized.onCompleted()
            break
        }
        
    }
    
    func requestAccessToEvents() {
        requestAccess(to: EKEntityType.event) { (accessGranted, error) in
            if accessGranted {
                print("access granted")
                self.authorized.onNext(true)
            } else if error != nil {
                self.authorized.onError(error!)
            } else {
                self.authorized.onNext(true)
            }
            self.authorized.onCompleted()
        }
    }
    
    func fetchEventsDetail() -> Observable<[CustomEvent]> {
        let calendars = self.calendars(for: .event)
        var retEvents = [CustomEvent]()
        // Get the current calendar with local time zone
        var currentCalendar = Calendar.current
        currentCalendar.timeZone = NSTimeZone.local
        // Get today's beginning & end
        let dateFrom = Date()
        let dateStart = currentCalendar.startOfDay(for: Date())
        let dateTo = currentCalendar.date(byAdding: .day, value: 1, to: dateStart)!
        // Note: Times are printed in UTC. Depending on where you live it won't print 00:00:00 but it will work with UTC times which can be converted to local time
        
        for calendar in calendars {
            
            let predicate = self.predicateForEvents(withStart: dateFrom as Date, end: dateTo as Date, calendars: [calendar])
            
            let events = self.events(matching: predicate)
            
            for event in events {
                retEvents
                    .append(
                        CustomEvent(
                            title: event.title,
                            startDate: event.startDate,
                            endDate: event.endDate))
            }
        }
        
        // sort events in start date ascending order
        retEvents = retEvents.sorted(by: { $0.startDate.compare($1.startDate) == .orderedAscending })
        
        return Observable.create({ (observer) -> Disposable in
            
            if retEvents.count > 0 {
                observer.onNext(retEvents)
                observer.onCompleted()
            }
            
            return Disposables.create()
        })
    }

}

struct CustomEvent: Equatable {
    var title = ""
    var startDate = Date()
    var endDate = Date()

    static func ==(lhs: CustomEvent, rhs: CustomEvent) -> Bool {
        return lhs.title == rhs.title && lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate && lhs.progress() == rhs.progress()
    }
    
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
    
    func progress() -> Double {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let remaining = Double(calendar.dateComponents([.second], from: Date(), to: endDate).second!)
        let duration = Double(calendar.dateComponents([.second], from: startDate, to: endDate).second!)
        //print("\(self.title) remaining: \(remaining) duration: \(duration)")
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
