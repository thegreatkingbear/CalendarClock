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
        case fetchEvents
        case observeEvents
        case loadCalendarSetting
        case observeCalendarSetting
        case fetchCurrentWeather
        case fetchFutureWeather
        case observeFirstCurrentWeather
        case observeFirstFutureWeather
        case displayLock
    }
    
    enum Mutation {
        case clicks
        case receiveEvents([CustomEvent])
        case receiveCurrentWeathers(CustomWeather)
        case receiveFutureWeathers([CustomWeather])
        case displayLocked
        case calendarSettingsLoaded([SectionedEventSettings])
    }
    
    struct State {
        var currentTime: String?
        var events: [SectionedEvents]?
        var weathers: CustomWeather? // description, icon, temp
        var futures: [SectionedWeathers]?
        var isDisplayLocked: Bool?
    }
    
    let initialState: State
    let eventStore = EventStore.shared()
    let weather = Weather()

    init() {
        self.initialState = State()
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .startClicking:
            return Observable<Int>.interval(1, scheduler: MainScheduler.instance)
                .map { _ in Mutation.clicks }
            
        case .fetchEvents: // interval : 1 minute = 60 seconds (considering clock changes every 1 minute)
            return Observable<Int>.interval(60, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .flatMap { _ in self.eventStore.authorized.asObservable() }
                .filter { $0 == true } // only when authorized
                .map { _ in self.eventStore.reset() } // to avoid 1019 error which occurs you fetch events just after aurhorizing
                .flatMap { _ in self.eventStore.selectedCalendars.asObservable() }
                .flatMap { self.eventStore.fetchEventsDetail(selected: $0) }
                .map { Mutation.receiveEvents($0) }
            
        case .observeEvents:
            return NotificationCenter.default.rx.notification(.EKEventStoreChanged)
                .flatMap { _ in self.eventStore.selectedCalendars.asObservable() }
                .flatMap { self.eventStore.fetchEventsDetail(selected: $0) }
                .map { Mutation.receiveEvents($0) }
            
        case .loadCalendarSetting:
            return self.eventStore.loadFromUserDefaults()
                .map { Mutation.calendarSettingsLoaded($0) }
            
        case .observeCalendarSetting:
            return self.eventStore.selectedCalendars.asObservable()
                .flatMap { self.eventStore.fetchEventsDetail(selected: $0)}
                .map { Mutation.receiveEvents($0) }
            
        case .fetchCurrentWeather: // interval : 1 hour = 3600 seconds
            return Observable<Int>.interval(3600, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in self.weather.coord.0 > 0 }
                .flatMap { _ in self.weather.fetchCurrentWeatherData() }
                .map { Mutation.receiveCurrentWeathers($0) }
            
        case .fetchFutureWeather: // interval : 2 hour = 7200 seconds
            return Observable<Int>.interval(7200, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in self.weather.coord.0 > 0 }
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
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case .clicks:
            var newState = state
            newState.currentTime = Clock.currentDateString()
            return newState
        case let .receiveEvents(events):
            var newState = state
            let sectionedEvents = SectionedEvents(header: "events", items: events)
            newState.events = [sectionedEvents]
            return newState
        case let .receiveCurrentWeathers(weathers):
            var newState = state
            newState.weathers = weathers
            return newState
        case let .receiveFutureWeathers(weathers):
            var newState = state
            let filtered = weathers.filter { $0.time != nil }
            let sectionedWeathers = SectionedWeathers(header: "something", items: filtered)
            newState.futures = [sectionedWeathers]
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
        }
    }
    
    func requestLocationAuthorization() {
        self.weather.verifyAuthorization()
    }
    
    func requestEventAuthorization() {
        self.eventStore.verifyAuthorityToEvents()
    }
}
