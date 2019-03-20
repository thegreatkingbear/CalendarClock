//
//  ViewController.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-02-15.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import UIKit
import EventKit
import ReactorKit
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional

class ViewController: UIViewController, StoryboardView {
    typealias Reactor = ViewReactor
    var disposeBag = DisposeBag()
    let dataSource = RxTableViewSectionedReloadDataSource<SectionedEvents>(configureCell:
    { dataSource, tableView, indexPath, item in
        print(item)
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! EventCell
        cell.title!.text = "\(item.title)"
        cell.period!.text = "\(item.period())"
        return cell
    })

    let weatherSource = RxCollectionViewSectionedReloadDataSource<SectionedWeathers>(configureCell:
    { dataSource, collectionView, indexPath, item in
        print(item)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WeatherCell", for: indexPath) as! WeatherCell
        cell.temp!.text = "\(item.temp!)"
        cell.icon!.image = item.icon
        cell.time!.text = "\(item.time!)"
        return cell
    })
    
    @IBOutlet weak var clockLabel: UILabel?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var currentDescription: UILabel?
    @IBOutlet weak var currentTemperature: UILabel?
    @IBOutlet weak var currentIcon: UIImageView?
    @IBOutlet weak var collectionView: UICollectionView?
    
    // hide status bar for aestheic reason
    override open var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func bind(reactor: Reactor) {
        print("bind method called")
        
        // calendar event authorization request (for event service)
        reactor.requestEventAuthorization()
        
        // location authorization request (for weather service)
        reactor.requestLocationAuthorization()
        
        // observe first location authorization and get the weather data
        reactor.action.onNext(.observeFirstCurrentWeather)
        reactor.action.onNext(.observeFirstFutureWeather)
        
        // start clock
        reactor.action.onNext(.startClicking)
        
        // fetch events
        reactor.action.onNext(.fetchEvents)
        
        // observe events
        reactor.action.onNext(.observeEvents)
        
        // fetch weathers
        reactor.action.onNext(.fetchCurrentWeather)
        
        // fetch future weathers
        reactor.action.onNext(.fetchFutureWeather)
        
        // clock state to view
        reactor.state.asObservable().map { $0.currentTime }
            .distinctUntilChanged()
            .bind(to: self.clockLabel!.rx.text)
            .disposed(by: self.disposeBag)
        
        // events state to view
        self.tableView!.rx.setDelegate(self).disposed(by: self.disposeBag)
        
        reactor.state.asObservable().map { $0.events }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .bind(to: self.tableView!.rx.items(dataSource: self.dataSource))
            .disposed(by: self.disposeBag)
        
        // current weather to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.description }
            .bind(to: self.currentDescription!.rx.text)
            .disposed(by: self.disposeBag)

        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.icon }
            .bind(to: self.currentIcon!.rx.image)
            .disposed(by: self.disposeBag)

        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.temp }
            .bind(to: self.currentTemperature!.rx.text)
            .disposed(by: self.disposeBag)
        
        // future weathers to view
        self.collectionView!.rx.setDelegate(self).disposed(by: self.disposeBag)

        reactor.state.asObservable().map { $0.futures }
            .filterNil()
            .filterEmpty()
            .distinctUntilChanged { $0 == $1 }
            .bind(to: self.collectionView!.rx.items(dataSource: self.weatherSource))
            .disposed(by: self.disposeBag)
    }

}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}


extension ObservableType where E: Sequence, E.Iterator.Element: Equatable {
    func distinctUntilChanged() -> Observable<E> {
        return distinctUntilChanged { (lhs, rhs) -> Bool in
            return Array(lhs) == Array(rhs)
        }
    }
}

// Event table view cell
class EventCell: UITableViewCell {
    @IBOutlet weak var title: UILabel?
    @IBOutlet weak var period: UILabel?
}

class WeatherCell: UICollectionViewCell {
    @IBOutlet weak var icon: UIImageView?
    @IBOutlet weak var time: UILabel?
    @IBOutlet weak var temp: UILabel?
}
