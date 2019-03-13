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
    var authorized = BehaviorSubject<Bool>(value: false)
    var currentWeather = PublishSubject<CustomWeather>()
    var futures = PublishSubject<[CustomWeather]>()
    var coord = (0.0, 0.0) // (lat, lon)
    
    // Initialization
    override init() {
        super.init()
        
        print("init event store")
        
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
            print("already authorized")
            authorized.onNext(true)
            //print("value of authorized subject: ", try! authorized.value())
            break
        case .restricted, .denied:
            authorized.onNext(false)
            //authorized.onCompleted()
        }
        
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
//        print("locations = \(locValue.latitude) \(locValue.longitude)")
        self.coord = (locValue.latitude, locValue.longitude)
        self.authorized.onNext(true)
        //self.authorized.onCompleted()
    }
    
    func requestAuthorization() {
        self.requestWhenInUseAuthorization()
    }
    
    func fetchCurrentWeatherData() {
        print("----------------fetching current weather--------------")

        let parameter: Parameters = [
            "appid": SECRET.WEATHER_API_KEY,
            "lat": self.coord.0,
            "lon": self.coord.1,
            "units": "metric"
        ]
        
        Alamofire.request("\(SECRET.URL_STRING)weather", method: .get, parameters: parameter)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                switch response.result {
                case .success(let json):
                    let dict = JSON(json)
                    var current = CustomWeather()
                    current.description = dict["weather"][0]["description"].description
                    let iconName = dict["weather"][0]["icon"].description
                    current.icon = UIImage(named: iconName)!.with(color: UIColor.lightGray)
                    current.temp = String(round(Double(dict["main"]["temp"].description)!)).split(separator: ".")[0] + "°"
                    self.currentWeather.onNext(current)
                    self.currentWeather.onCompleted()
                case .failure(let error):
                    print(error.localizedDescription)
                }
        }
    }
    
    func fetchFutureWeatherData() {
        print("----------------fetching future weather--------------")
        let parameter: Parameters = [
            "appid": SECRET.WEATHER_API_KEY,
            "lat": self.coord.0,
            "lon": self.coord.1,
            "units": "metric"
        ]
        
        Alamofire.request("\(SECRET.URL_STRING)forecast", method: .get, parameters: parameter)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                switch response.result {
                case .success(let json):
                    var ret = [CustomWeather()]
                    let dicts = JSON(json)
                    for dict in dicts["list"].arrayValue {
                        var item = CustomWeather()
                        item.description = dict["weather"][0]["description"].description
                        let iconName = dict["weather"][0]["icon"].description
                        item.icon = UIImage(named: iconName)!.with(color: UIColor.gray)
                        item.temp = String(round(Double(dict["main"]["temp"].description)!)).split(separator: ".")[0] + "°"
                        item.time = self.convertUnixTimeToString(dt: Double(dict["dt"].description)!)
                        ret.append(item)
                    }
                    self.futures.onNext(ret)
                    self.futures.onCompleted()
                case .failure(let error):
                    print(error.localizedDescription)
                }
        }
    }
    
    // convert dt to 2 + 2 digit string
    private func convertUnixTimeToString(dt: Double) -> String {
        let date = Date(timeIntervalSince1970: dt)
        let hour = Calendar.current.component(.hour, from: date)
        let day = Calendar.current.component(.day, from: date)
        return String(format:"%02d", hour) + "/" + String(format:"%02d", day)
    }
    
}

struct CustomWeather: Equatable {
    var description: String?
    var icon: UIImage?
    var temp: String?
    var time: String?

    static func ==(lhs: CustomWeather, rhs: CustomWeather) -> Bool {
        return lhs.description == rhs.description && lhs.temp == rhs.temp && lhs.time == rhs.time
    }
}

struct SectionedWeathers: Equatable {
    var header: String
    var items: [Item]
    
    static func ==(lhs: SectionedWeathers, rhs: SectionedWeathers) -> Bool {
        return lhs.header == rhs.header && lhs.items == rhs.items
    }
}

extension SectionedWeathers: SectionModelType {
    typealias Item = CustomWeather
    
    init(original: SectionedWeathers, items: [Item]) {
        self = original
        self.items = items
    }
}
