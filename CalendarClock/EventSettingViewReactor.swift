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
            return self.mergeCalendars().asObservable()
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
    
    private func mergeCalendars() -> Observable<[SectionedEventSettings]> {
        return Observable.combineLatest(
            self.eventStore.fetchCalendars(),
            self.eventStore.loadFromUserDefaults(),
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
                for i in 0..<groupedCalendars.count {
                    for j in 0..<loadedCalendars.count {
                        if groupedCalendars[i].header == loadedCalendars[j].header {
                            for k in 0..<loadedCalendars[j].items.count {
                                for l in 0..<groupedCalendars[i].items.count {
                                    if loadedCalendars[j].items[k].identifier == groupedCalendars[i].items[l].identifier {
                                        groupedCalendars[i].items[l].isSelected = loadedCalendars[j].items[k].isSelected
                                    }
                                }
                            }
                        }
                    }
                }
                
                return groupedCalendars
        })
    }
    
}
