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
    }
    
    enum Mutation {
        case clicks
        case requestEvents([CustomEvent])
    }
    
    struct State {
        var currentTime: String?
        var events: [SectionedEvents]
    }
    
    let initialState: State
    
    init() {
        print("init clock view reactor")
        self.initialState = State(
            currentTime: "Initializing clock",
            events: [SectionedEvents(header: "something", items: [])]
        )
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .startClicking:
            return Observable<Int>.interval(1, scheduler: MainScheduler.instance)
                .map { _ in Mutation.clicks }
        case .fetchEvents:
            return self.requestCalendarEvents().map { events in
                Mutation.requestEvents(events)
            }
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case .clicks:
            var newState = state
            newState.currentTime = Clock.currentDateString()
            return newState
        case let .requestEvents(events):
            //print("request events : ", events!.description)
            var newState = state
            let sectionedEvents = SectionedEvents(header: "something", items: events)
            print(sectionedEvents.items.description)
            newState.events = [sectionedEvents]
            return newState
        }
    }
    
    private func requestCalendarEvents() -> Observable<[CustomEvent]> {
        print("request calendar events")

        return Observable.create({ (observer) -> Disposable in
            // 아래에 결과값을 그냥 dispose 시키면 바로 없어져버린다 (사실상 값을 subscribe 할 수가 없다)
            // 그렇다면, 어떻게 dispose 시켜줘야 하나? 패턴상으로는 diposeBag은 view controller에 위치하는 것으로 보인다.
            _ = EventStore.standard.authorized.asObservable().subscribe { (authorized) in
                print("authorized : ", authorized)
                if let flag = authorized.element, flag == true {
                    observer.onNext(EventStore.fetchEventsDetail())
                    observer.onCompleted()
                }
            }
            
            EventStore.verifyAuthorityToEvents()
            
            return Disposables.create()
        })

    }
}
