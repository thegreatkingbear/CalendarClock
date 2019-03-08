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
            print("already authorized")
            authorized.onNext(true)
            print("value of authorized subject: ", try! authorized.value())
            break
        case .restricted, .denied:
            authorized.onNext(false)
            authorized.onCompleted()
        }
        
    }
    
    func requestAccessToEvents() {
        requestAccess(to: EKEntityType.event) { (accessGranted, error) in
            if accessGranted {
                print("access granted")
                self.authorized.onNext(true)
            } else if error != nil {
                self.authorized.onError(error!)
                self.authorized.onCompleted()
            } else {
                self.authorized.onNext(true)
                self.authorized.onCompleted()
            }
        }
    }
    
    func fetchEventsDetail() -> [CustomEvent] {
        let calendars = self.calendars(for: .event)
        var retEvents = [CustomEvent]()
        let oneMonthAgo = NSDate(timeIntervalSinceNow: -1*24*3600)
        let oneMonthAfter = NSDate(timeIntervalSinceNow: +1*24*3600)

        for calendar in calendars {
            
            let predicate = self.predicateForEvents(withStart: oneMonthAgo as Date, end: oneMonthAfter as Date, calendars: [calendar])
            
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
