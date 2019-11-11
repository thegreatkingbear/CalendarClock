//
//  EventSettingViewReactor.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-03-21.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation
import ReactorKit
import RxSwift
import RxCocoa
import EventKit

class EventSettingViewReactor: Reactor {
    
    enum Action {
        case fetchCalendars
        case saveChanges((Int, Int)) // section, row
    }
    
    enum Mutation {
        case receiveCalendars([SectionedEventSettings])
        case updateCalendar((Int, Int)) // section, row
    }
    
    struct State {
        var calendars: [SectionedEventSettings]?
    }
    
    let initialState: State
    let eventStore = CalendarEvent.shared()
    
    init() {
        self.initialState = State()
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .fetchCalendars:
            return self.eventStore.mergeCalendars().asObservable()
                .map { Mutation.receiveCalendars($0) }
        case let .saveChanges(index):
            return Observable.just(Mutation.updateCalendar(index))
                .do { self.eventStore.saveToUserDefaults(settings: self.currentState.calendars!) } // side effect
                .do { self.eventStore.collectSelectedCalendarIdentifiers(calendars: self.currentState.calendars!) } // side effect 2
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case let .receiveCalendars(calendars):
            var newState = state
            newState.calendars = calendars
            return newState
        case let .updateCalendar(index):
            var newState = state
            if var calendars = newState.calendars {
                calendars[index.0].items[index.1].isSelected.toggle()
                newState.calendars = calendars
            }
            return newState
        }
    }
    
    
}
