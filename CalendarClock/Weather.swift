//
//  Weather.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-03-10.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation
import CoreLocation
import RxSwift
import Alamofire
import SwiftyJSON
import SwiftyImage
import RxDataSources

class Weather: CLLocationManager, CLLocationManagerDelegate {
    
    // MARK: - Variables
    var coord = (-1.0, -1.0) // (lat, lon)
    var locationJustFetched = PublishSubject<Bool>()
    var isFirstLocationFetch = true
    
    // Initialization
    override init() {
        super.init()
        
        self.delegate = self
        self.desiredAccuracy = kCLLocationAccuracyBest
        self.startUpdatingLocation()
    }

    func verifyAuthorization() {
        
        let status = CLLocationManager.authorizationStatus()
        
        switch (status) {
        case .notDetermined:
            requestAuthorization()
            break
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .restricted, .denied:
            break
        }
        
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        self.coord = (locValue.latitude, locValue.longitude)
        
        // alert first time location fetch to the steam
        if isFirstLocationFetch {
            isFirstLocationFetch = false
            self.locationJustFetched.onNext(true)
            self.locationJustFetched.onCompleted()
        }
    }
    
    func requestAuthorization() {
        self.requestWhenInUseAuthorization()
    }
    
    func fetchCurrentWeatherData() -> Observable<Condition> {
        print("----------------fetching current weather--------------")

        let parameter: Parameters = [
            "appid": SECRET.WEATHER_API_KEY,
            "lat": self.coord.0,
            "lon": self.coord.1,
            "units": "metric"
        ]
        
        return Observable.create({ (observer) -> Disposable in
            Alamofire.request("\(SECRET.URL_STRING)weather", method: .get, parameters: parameter)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    let current: Result<Condition> = JSONDecoder().decodeResponse(from: response)
                    switch current {
                        case .success(let condition):
//                            print(condition)
                            observer.onNext(condition)
                            observer.onCompleted()
                        case .failure(let error):
                            print(error)
                            observer.onCompleted()
                    }
                }
            return Disposables.create()
        })
    }
    
    func fetchFutureWeatherData() -> Observable<[Condition]> {
        print("----------------fetching future weather--------------")
        let parameter: Parameters = [
            "appid": SECRET.WEATHER_API_KEY,
            "lat": self.coord.0,
            "lon": self.coord.1,
            "units": "metric"
        ]
        
        return Observable.create({ (observer) -> Disposable in
            Alamofire.request("\(SECRET.URL_STRING)forecast", method: .get, parameters: parameter)
                .validate(statusCode: 200..<300)
                .responseData { response in
                    let futures: Result<FutureCondition> = JSONDecoder().decodeResponse(from: response)
                    switch futures {
                        case .success(let futures):
//                            print(futures)
                            observer.onNext(futures.list)
                            observer.onCompleted()
                        case .failure(let error):
                            print(error)
                            observer.onCompleted()
                    }
                }
            return Disposables.create()
        })
    }
    
}

struct SectionedWeathers: Equatable {
    var header: (String, String)
    var items: [Item]
    
    static func ==(lhs: SectionedWeathers, rhs: SectionedWeathers) -> Bool {
        return lhs.header == rhs.header && lhs.items == rhs.items
    }
}

extension SectionedWeathers: SectionModelType {
    typealias Item = Condition
    
    init(original: SectionedWeathers, items: [Item]) {
        self = original
        self.items = items
    }
}


extension JSONDecoder {
    func decodeResponse<T: Decodable>(from response: DataResponse<Data>) -> Result<T> {
        guard response.error == nil else {
            print(response.error!)
            return .failure(response.error!)
        }

        guard let responseData = response.data else {
            print("didn't get any data from API")
            return .failure(BackendError.parsing(reason: "Did not get data in response"))
        }

        do {
            let item = try decode(T.self, from: responseData)
            return .success(item)
        } catch {
            print("error trying to decode response")
            print(error)
            return .failure(error)
        }
    }
}

enum BackendError: Error {
    case urlError(reason: String)
    case objectSerialization(reason: String)
    case parsing(reason: String)
}
