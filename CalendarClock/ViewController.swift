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
import Toast_Swift

class ViewController: UIViewController, StoryboardView, UIPopoverPresentationControllerDelegate {
    typealias Reactor = ViewReactor
    var disposeBag = DisposeBag()
    
    // event cell setup
    let dataSource = RxTableViewSectionedReloadDataSource<SectionedEvents>(configureCell:
    { dataSource, tableView, indexPath, item in
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! EventCell
        cell.title!.text = "\(item.title)"
        cell.period!.text = "\(item.period())"
        cell.pie?.isHidden = item.progress() < 0 ? true : false
        cell.pie?.progress = item.progress() > 0 ? CGFloat(item.progress()) : 0
        return cell
    })

    // weather forecast cell setup
    let weatherSource = RxCollectionViewSectionedReloadDataSource<SectionedWeathers>(configureCell:
    { dataSource, collectionView, indexPath, item in
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
    @IBOutlet weak var calendarSettingButton: UIButton?
    @IBOutlet weak var displayLockButton: UIButton?
    
    // display on is UI feature 
    var insomnia = Insomnia(mode: .whenCharging)
    
    // hide status bar for aestheic reason
    override open var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // toast style setting
        var style = ToastStyle()
        style.backgroundColor = .darkGray
        style.titleColor = .lightGray
        ToastManager.shared.style = style
    }
    
    func bind(reactor: Reactor) {
        // calendar event authorization request (for event service)
        reactor.requestEventAuthorization()
        
        // location authorization request (for weather service)
        reactor.requestLocationAuthorization()
        
        // observe first location authorization and get the weather data
        reactor.action.onNext(.observeFirstCurrentWeather)
        reactor.action.onNext(.observeFirstFutureWeather)
        
        // start clock
        reactor.action.onNext(.startClicking)
        
        // load calendar settings
        reactor.action.onNext(.loadCalendarSetting)
        
        // fetch events
        reactor.action.onNext(.fetchEvents)
        
        // observe events
        reactor.action.onNext(.observeEvents)
        reactor.action.onNext(.observeCalendarSetting)
        
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
            //.distinctUntilChanged { $0 == $1 }
            .bind(to: self.tableView!.rx.items(dataSource: self.dataSource))
            .disposed(by: self.disposeBag)
        
        // for later use: view communication through delegation-like pattern
        let calendarSettingView = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "CalendarSetting") as! EventSettingViewController
        
        // pop up calendar setting table view over event table view
        self.tableView!.rx.itemSelected.subscribe(onNext: { indexPath in
            calendarSettingView.reactor = EventSettingViewReactor()
            calendarSettingView.preferredContentSize = CGSize(width: 350, height: 300)
            calendarSettingView.modalPresentationStyle = .popover
            let popover = AlwaysPresentAsPopover.configurePresentation(forController: calendarSettingView)
            popover.sourceView = self.tableView!
            popover.sourceRect = self.tableView!.bounds
            popover.permittedArrowDirections = .down
            self.present(calendarSettingView, animated: true, completion: nil)
        }).disposed(by: self.disposeBag)
        
        // current weather description to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.description }
            .bind(to: self.currentDescription!.rx.text)
            .disposed(by: self.disposeBag)

        // current weather icon image to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.icon }
            .bind(to: self.currentIcon!.rx.image)
            .disposed(by: self.disposeBag)

        // current weather temperature to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.temp }
            .bind(to: self.currentTemperature!.rx.text)
            .disposed(by: self.disposeBag)
        
        // future weathers to view(set delegate)
        self.collectionView!.rx.setDelegate(self).disposed(by: self.disposeBag)

        // forecast items to collection view
        reactor.state.asObservable().map { $0.futures }
            .filterNil()
            .filterEmpty()
            .distinctUntilChanged { $0 == $1 }
            .bind(to: self.collectionView!.rx.items(dataSource: self.weatherSource))
            .disposed(by: self.disposeBag)
        
        // calendar setting button (in case there is no cell in event table)
        self.calendarSettingButton!.rx.tap
            .subscribe(onNext: {
                calendarSettingView.reactor = EventSettingViewReactor()
                calendarSettingView.preferredContentSize = CGSize(width: 350, height: 300)
                calendarSettingView.modalPresentationStyle = .popover
                let popover = AlwaysPresentAsPopover.configurePresentation(forController: calendarSettingView)
                popover.sourceView = self.calendarSettingButton!
                popover.sourceRect = self.calendarSettingButton!.bounds
                popover.permittedArrowDirections = .down
                self.present(calendarSettingView, animated: true, completion: nil)
            })
            .disposed(by: self.disposeBag)
        
        // display lock button wired
        self.displayLockButton!.rx.tap
            .map { Reactor.Action.displayLock }
            .bind(to: reactor.action)
            .disposed(by: self.disposeBag)
        
        // display always-on or when-charging UI logic
        reactor.state.asObservable().map { $0.isDisplayLocked }
            .distinctUntilChanged()
            .filterNil()
            .subscribe( onNext: {
                print($0)
                let imageName = $0 ? "locked" : "unlocked"
                let text = $0 ? "display is set to always on" : "display keeps on only when charging"
                self.displayLockButton!.setImage(UIImage(named: imageName), for: .normal)
                self.insomnia.mode = $0 ? .always : .whenCharging
                self.view.makeToast(text)
            })
            .disposed(by: self.disposeBag)
    }

}

// event table view cell height
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
    @IBOutlet weak var pie: PieProgressView?
}

// weather forecast collection view cell
class WeatherCell: UICollectionViewCell {
    @IBOutlet weak var icon: UIImageView?
    @IBOutlet weak var time: UILabel?
    @IBOutlet weak var temp: UILabel?
}

// this is because iphone does not pop over in ipad style.
class AlwaysPresentAsPopover: NSObject, UIPopoverPresentationControllerDelegate {
    
    // `sharedInstance` because the delegate property is weak - the delegate instance needs to be retained.
    private static let sharedInstance = AlwaysPresentAsPopover()
    
    private override init() {
        super.init()
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    static func configurePresentation(forController controller : UIViewController) -> UIPopoverPresentationController {
        controller.modalPresentationStyle = .popover
        let presentationController = controller.presentationController as! UIPopoverPresentationController
        presentationController.delegate = AlwaysPresentAsPopover.sharedInstance
        return presentationController
    }
    
}
