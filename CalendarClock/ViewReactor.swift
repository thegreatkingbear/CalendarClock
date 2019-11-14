//
//  File.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-02-17.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation
import ReactorKit
import RxSwift
import RxCocoa
import EventKit

class ViewReactor: Reactor {

    enum Action {
        case startClicking
        case updateEventsOnClock
        case fetchEvents
        case observeEvents
        case observeEventsAuthorization
        case loadCalendarSetting
        case observeCalendarSetting
        case fetchCurrentWeather
        case fetchFutureWeather
        case observeFirstCurrentWeather
        case observeFirstFutureWeather
        case displayLock
        case deleteEvent(IndexPath)
        case undoDelete
    }
    
    enum Mutation {
        case clicks
        case updateEventsOnClock
        case receiveEvents([CustomEvent])
        case receiveCurrentWeathers(CustomWeather)
        case receiveFutureWeathers([CustomWeather])
        case displayLocked
        case calendarSettingsLoaded([SectionedEventSettings])
        case deleteEvent(IndexPath)
        case undoDelete
    }
    
    struct State {
        var currentTime: String?
        var currentDate: String?
        var events: [SectionedEvents]?
        var weathers: CustomWeather? // description, icon, temp
        var futures: [SectionedWeathers]?
        var isDisplayLocked: Bool?
        var editedEvents: [CustomEvent] = [CustomEvent]()
    }
    
    let initialState: State
    let eventStore = CalendarEvent.shared()
    let weather = Weather()

    init() {
        self.initialState = State()
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .startClicking:
            return Observable<Int>.interval(1, scheduler: MainScheduler.instance)
                .map { _ in Mutation.clicks }
            
        case .updateEventsOnClock:
            return Observable<Int>.interval(1, scheduler: MainScheduler.instance)
                .map { _ in Mutation.updateEventsOnClock }
            
        case .fetchEvents: // interval : 1 minute = 60 seconds (considering clock changes every 1 minute)
            return Observable<Int>.interval(60, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in try! self.eventStore.authorized.value() == true } // only when authorized
                .flatMap { _ in self.eventStore.mergeCalendars() }
                .flatMap { _ in self.eventStore.selectedCalendars.asObservable() }
                .flatMap { _ in self.eventStore.fetchEventsDetail() }
                .map { Mutation.receiveEvents($0) }
            
        case .observeEvents:
            return NotificationCenter.default.rx.notification(.EKEventStoreChanged)
                .flatMap { _ in self.eventStore.selectedCalendars.asObservable() }
                .flatMap { _ in self.eventStore.fetchEventsDetail() }
                .map { Mutation.receiveEvents($0) }
            
        case .observeEventsAuthorization:
            return self.eventStore.authorized.asObservable()
                .flatMap { _ in self.eventStore.mergeCalendars() }
                .flatMap { _ in self.eventStore.fetchEventsDetail() }
                .map { Mutation.receiveEvents($0) }

        case .loadCalendarSetting:
            return self.eventStore.mergeCalendars()
                .map { Mutation.calendarSettingsLoaded($0) }
            
        case .observeCalendarSetting:
            return self.eventStore.selectedCalendars.asObservable()
                .flatMap { _ in self.eventStore.fetchEventsDetail() }
                .map { Mutation.receiveEvents($0) }
            
        case .fetchCurrentWeather: // interval : 1 hour = 3600 seconds
            return Observable<Int>.interval(3600, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in !(self.weather.coord.0 == 0 && self.weather.coord.1 == 0)}
                .flatMap { _ in self.weather.fetchCurrentWeatherData() }
                .map { Mutation.receiveCurrentWeathers($0) }
            
        case .fetchFutureWeather: // interval : 2 hour = 7200 seconds
            return Observable<Int>.interval(7200, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in !(self.weather.coord.0 == 0 && self.weather.coord.1 == 0) }
                .flatMap { _ in self.weather.fetchFutureWeatherData() }
                .map { Mutation.receiveFutureWeathers($0) }
            
        case .observeFirstCurrentWeather:
            return self.weather.locationJustFetched.asObservable()
                .flatMap { _ in self.weather.fetchCurrentWeatherData() }
                .map { Mutation.receiveCurrentWeathers($0) }
        
        case .observeFirstFutureWeather:
            return self.weather.locationJustFetched.asObservable()
                .flatMap { _ in self.weather.fetchFutureWeatherData() }
                .map { Mutation.receiveFutureWeathers($0) }
            
        case .displayLock:
            return Observable.just(Mutation.displayLocked)
            
        case let .deleteEvent(indexpath):
            return Observable.just(Mutation.deleteEvent(indexpath))
            
        case .undoDelete:
            return Observable.concat([
                Observable.just(Mutation.undoDelete),
                
                self.eventStore.selectedCalendars.asObservable()
                    .flatMap { _ in self.eventStore.fetchEventsDetail() }
                    .map { Mutation.receiveEvents($0) }
            ])
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
            
        case .clicks:
            var newState = state
            newState.currentTime = Clock.currentDateString()
            newState.currentDate = Clock.currentDayString()
            return newState
            
        case .updateEventsOnClock:
            var newState = state
            let events = state.events!
            var newEvents = [SectionedEvents]()
            for event in events {
                var newEvent = event
                var newItems = [CustomEvent]()
                for item in event.items {
                    var newItem = item
                    newItem.timeDiff()
                    newItems.append(newItem)
                }
                newEvent.items = newItems
                newEvents.append(newEvent)
            }
            newState.events = newEvents
            return newState
            
        case let .receiveEvents(events):
            var newState = state
            let filtered = events.filter { !state.editedEvents.contains($0) }
            let sectionedEvents = SectionedEvents(header: "events", items: filtered)
            newState.events = [sectionedEvents]
            return newState
            
        case let .receiveCurrentWeathers(weathers):
            var newState = state
            newState.weathers = weathers
            return newState
            
        case let .receiveFutureWeathers(weathers):
            var newState = state
            let filtered = weathers.filter { $0.day != nil } // to avoid crash when it fetches first time
            newState.futures = self.collectSectionedWeathers(weathers: filtered)
            return newState
            
        case .displayLocked:
            var newState = state
            let isDisplayLocked = state.isDisplayLocked ?? false
            newState.isDisplayLocked = isDisplayLocked ? false : true
            return newState
            
        case let .calendarSettingsLoaded(settings):
            let newState = state
            // this seems not good. I know. But event store holds the variable which emits changes in calendar settings
            self.eventStore.collectSelectedCalendarIdentifiers(calendars: settings)
            return newState
            
        case let .deleteEvent(indexpath):
            var newState = state
            
            // because of time difference between tableview cell disappearance,
            // which is late, and real indexpath of sectioned events,
            // fast fingers often cause index out of range errors
            // below safe guard this problem
            guard var event = state.events![0].items[safe: indexpath.row] else {
                return newState
            }
            event.isVisible = false
            newState.editedEvents.append(event)
            
            let events = state.events![0].items
            let filtered = events.filter { !newState.editedEvents.contains($0) }
            let sectionedEvents = SectionedEvents(header: "events", items: filtered)
            newState.events = [sectionedEvents]
            return newState

        case .undoDelete:
            var newState = state
            newState.editedEvents = [CustomEvent]()
            return newState
        }
    }
    
    func requestLocationAuthorization() {
        self.weather.verifyAuthorization()
    }
    
    func requestEventAuthorization() {
        self.eventStore.verifyAuthorityToEvents()
    }
    
    func collectSectionedWeathers(weathers: [CustomWeather]) -> [SectionedWeathers] {
        // reorganize fetched weathers into sectioned table view rows
        let sorted = weathers.sorted { $0.unixTime! < $1.unixTime! }
        let grouped = sorted.reduce([SectionedWeathers]()) {
            guard var last = $0.last else { return [SectionedWeathers(header: (String($1.day!), $1.weekday!), items: [$1])] }
            var collection = $0
            if last.header.0 == String($1.day!) {
                last.items += [$1]
                collection[collection.count - 1] = last
            } else {
                collection += [SectionedWeathers(header: (String($1.day!), $1.weekday!), items: [$1])]
            }
            return collection
        }
        return grouped
    }
}

extension Collection where Indices.Iterator.Element == Index {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
