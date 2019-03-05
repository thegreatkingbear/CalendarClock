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

class EventStore {
    
    // MARK: - Properties
    static let standard = EventStore()
    
    // MARK: - Variables
    var authorized = BehaviorSubject<Bool>(value: false)
    static let eventStore = EKEventStore.init()

    
    // Initialization
    private init() {
        print("init event")
    }
    
    
    static func verifyAuthorityToEvents() {
        
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)

        switch (status) {
        case .notDetermined:
            requestAccessToEvents()
            break
        case .authorized:
            print("already authorized")
            standard.authorized.onNext(true)
            print("value of authorized subject: ", try! standard.authorized.value())
            break
        case .restricted, .denied:
            standard.authorized.onNext(false)
            standard.authorized.onCompleted()
        }
        
    }
    
    static func requestAccessToEvents() {
        eventStore.requestAccess(to: EKEntityType.event) { (accessGranted, error) in
            if accessGranted {
                print("access granted")
                standard.authorized.onNext(true)
            } else if error != nil {
                standard.authorized.onError(error!)
                standard.authorized.onCompleted()
            } else {
                standard.authorized.onNext(true)
                standard.authorized.onCompleted()
            }
        }
    }
    
    static func fetchEventsDetail() -> [CustomEvent] {
        let calendars = eventStore.calendars(for: .event)
        var retEvents = [CustomEvent]()
        let oneMonthAgo = NSDate(timeIntervalSinceNow: -1*24*3600)
        let oneMonthAfter = NSDate(timeIntervalSinceNow: +1*24*3600)

        for calendar in calendars {
            
            let predicate = eventStore.predicateForEvents(withStart: oneMonthAgo as Date, end: oneMonthAfter as Date, calendars: [calendar])
            
            let events = eventStore.events(matching: predicate)
            
            for event in events {
                retEvents
                    .append(
                        CustomEvent(
                            title: event.title,
                            startDate: event.startDate,
                            endDate: event.endDate))
            }
        }
        return retEvents
    }

}

struct CustomEvent: Equatable {
    var title = ""
    var startDate = Date()
    var endDate = Date()

    static func ==(lhs: CustomEvent, rhs: CustomEvent) -> Bool {
        return lhs.title == rhs.title && lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate
    }
}
