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
        case fetchWeather
        case fetchFutureWeather
    }
    
    enum Mutation {
        case clicks
        case receiveEvents([CustomEvent])
        case receiveWeathers(CustomWeather)
        case receiveFutureWeathers([CustomWeather])
    }
    
    struct State {
        var currentTime: String?
        var events: [SectionedEvents]?
        var weathers: CustomWeather? // description, icon, temp
        var futures: [SectionedWeathers]?
    }
    
    let initialState: State
    let eventStore = EventStore()
    let weather = Weather()
    let observeEvent = NotificationCenter.default.rx.notification(.EKEventStoreChanged)
    
    init() {
        print("init clock view reactor")
        self.initialState = State()
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .startClicking:
            return Observable<Int>.interval(1, scheduler: MainScheduler.instance)
                .map { _ in Mutation.clicks }
        case .fetchEvents:
            return self.requestCalendarEvents().map { events in
                Mutation.receiveEvents(events)
            }
        case .observeEvents:
            return NotificationCenter.default.rx.notification(.EKEventStoreChanged)
                .map({ (event) in
                    self.requestCalendarEvents().map { events in
                        Mutation.receiveEvents(events)
                    }
                })
                .merge()
        case .fetchWeather:
            return Observable<Int>.interval(10, scheduler: MainScheduler.instance)
                .flatMap { _ in self.requestCurrentWeather() }
                .map { Mutation.receiveWeathers($0) }
        case .fetchFutureWeather:
            return self.requestFutureWeather().map { weathers in
                Mutation.receiveFutureWeathers(weathers)
            }
        }
        
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case .clicks:
            var newState = state
            newState.currentTime = Clock.currentDateString()
            return newState
        case let .receiveEvents(events):
            //print("request events : ", events!.description)
            var newState = state
            let sectionedEvents = SectionedEvents(header: "something", items: events)
            print(sectionedEvents.items.description)
            newState.events = [sectionedEvents]
            return newState
        case let .receiveWeathers(weathers):
            var newState = state
            print("received current : ", weathers)
            newState.weathers = weathers
            return newState
        case let .receiveFutureWeathers(weathers):
            var newState = state
            let filtered = weathers.filter { $0.time != nil }
            let sectionedWeathers = SectionedWeathers(header: "something", items: filtered)
            print("received futures : ", sectionedWeathers.items.description)
            newState.futures = [sectionedWeathers]
            return newState
        }
    }
    
    private func requestCalendarEvents() -> Observable<[CustomEvent]> {
        print("request calendar events")

        return Observable.create({ (observer) -> Disposable in
            // 아래에 결과값을 그냥 dispose 시키면 바로 없어져버린다 (사실상 값을 subscribe 할 수가 없다)
            // 그렇다면, 어떻게 dispose 시켜줘야 하나? 패턴상으로는 diposeBag은 view controller에 위치하는 것으로 보인다.
            _ = self.eventStore.authorized.asObservable().subscribe { (authorized) in
                print("authorized events: ", authorized)
                if let flag = authorized.element, flag == true {
                    observer.onNext(self.eventStore.fetchEventsDetail())
                    observer.onCompleted()
                }
            }
            
            self.eventStore.verifyAuthorityToEvents()
            
            return Disposables.create()
        })
    }
    
    private func requestCurrentWeather() -> Observable<CustomWeather> {
        print("request current weather")
        
        return Observable.create({ (observer) -> Disposable in
            _ = self.weather.authorized.asObservable().subscribe { authorized in
                print("authorized weather: ", authorized)
                if let flag = authorized.element, flag == true, self.weather.coord.0 != 0 {
                    self.weather.fetchCurrentWeatherData()
                    _ = self.weather.currentWeather.asObservable().subscribe { current in
                        print("current weather : ", current)
                        if let element = current.element {
                            observer.onNext(element)
                            //observer.onCompleted()
                        }
                    }
                }
            }
            
            self.weather.verifyAuthorization()
            
            return Disposables.create()
        })
    }
    
    private func requestFutureWeather() -> Observable<[CustomWeather]> {
        print("request future weather")
        
        return Observable.create({ (observer) -> Disposable in
            _ = self.weather.authorized.asObservable().subscribe { authorized in
                print("authorized future: ", authorized)
                if let flag = authorized.element, flag == true, self.weather.coord.0 != 0 {
                    self.weather.fetchFutureWeatherData()
                    _ = self.weather.futures.asObservable().subscribe { futures in
                        print("future weather : ", futures)
                        if let element = futures.element {
                            observer.onNext(element)
                            observer.onCompleted()
                        }
                    }
                }
            }
            
            self.weather.verifyAuthorization()
            
            return Disposables.create()
        })
    }
}
