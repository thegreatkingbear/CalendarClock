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

class ViewController: UIViewController, StoryboardView, UIPopoverPresentationControllerDelegate, UICollectionViewDelegateFlowLayout {
    typealias Reactor = ViewReactor
    var disposeBag = DisposeBag()
    
    // event cell setup
    let dataSource = RxTableViewSectionedReloadDataSource<SectionedEvents>(configureCell:
    { dataSource, tableView, indexPath, item in
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! EventCell
        // for double check purpose (ocassionally interface builder setting does not comply)
        cell.backgroundColor = UIColor.clear
        cell.title!.text = "\(item.title)"
        cell.period!.text = "\(item.period())"
        cell.pie?.isHidden = item.progress() < 0 ? true : false
        cell.pie?.progress = item.progress() > 0 ? CGFloat(item.progress()) : 0
        return cell
    })

    // weather forecast cell setup
    let weatherSource = RxCollectionViewSectionedReloadDataSource<SectionedWeathers>(
        configureCell: // cell
        { dataSource, collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WeatherCell", for: indexPath) as! WeatherCell
            cell.temp!.text = String(round(item.main.temp)).split(separator: ".")[0] + "°"
            cell.icon!.image = UIImage(named: item.weather[0].icon)!.with(color: UIColor.lightGray)
            cell.time!.text = "\(item.hour())"
            return cell
        },
        configureSupplementaryView: // section header
        { dataSource, collectionView, kind, indexPath in
            let section = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "WeatherHeader", for: indexPath) as! WeatherHeader
            section.day!.text = "\(dataSource[indexPath.section].header.0)"
            section.weekday!.text = "\(dataSource[indexPath.section].header.1)"
            return section
        }
    )
    
    @IBOutlet weak var clockLabel: UILabel?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var currentDescription: UILabel?
    @IBOutlet weak var currentTemperature: UILabel?
    @IBOutlet weak var currentIcon: UIImageView?
    @IBOutlet weak var collectionView: UICollectionView?
    @IBOutlet weak var calendarSettingButton: UIButton?
    @IBOutlet weak var displayLockButton: UIButton?
    @IBOutlet weak var undoButton: UIButton?
    
    // constraints for changing orientations
    @IBOutlet weak var clockXPositionLandscape: NSLayoutConstraint?
    @IBOutlet weak var clockXPositionPortrait: NSLayoutConstraint?
    @IBOutlet weak var currentIconXPositionLandscape: NSLayoutConstraint?
    @IBOutlet weak var currentIconXPositionPortrait: NSLayoutConstraint?
    @IBOutlet weak var currentDescriptionWidthLandscape: NSLayoutConstraint?
    @IBOutlet weak var currentDescriptionWidthPortrait: NSLayoutConstraint?
    @IBOutlet weak var weathersWidthLandscape: NSLayoutConstraint?
    @IBOutlet weak var weathersWidthPortrait: NSLayoutConstraint?
    @IBOutlet weak var weathersXPositionLandscape: NSLayoutConstraint?
    @IBOutlet weak var weathersXPositionPortrait: NSLayoutConstraint?
    @IBOutlet weak var tableWidthLandscape: NSLayoutConstraint?
    @IBOutlet weak var tableWidthPortrait: NSLayoutConstraint?
    @IBOutlet weak var tableXPositionLandscape: NSLayoutConstraint?
    @IBOutlet weak var tableXPositionPortrait: NSLayoutConstraint?
    @IBOutlet weak var tableTopLandscape: NSLayoutConstraint?
    @IBOutlet weak var tableTopPortrait: NSLayoutConstraint?
    
    
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
        
        // for double check purpose (ocassionally interface builder setting does not comply)
        self.collectionView!.backgroundColor = UIColor.clear
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        // to detect orientations at start-up
        self.applyOrientations()
        
    }
    
    func bind(reactor: Reactor) {
        // for enabling swipe to delete action
        dataSource.canEditRowAtIndexPath = { dataSource, indexPath in
            if self.tableView!.isEditing { return false }
            return true
        }
        
        // calendar event authorization request (for event service)
        reactor.requestEventAuthorization()
        
        // location authorization request (for weather service)
        reactor.requestLocationAuthorization()
        
        // observe first location authorization and get the weather data
        reactor.action.onNext(.observeFirstCurrentWeather)
        reactor.action.onNext(.observeFirstFutureWeather)
        
        // start clock
        reactor.action.onNext(.startClicking)
        reactor.action.onNext(.updateEventsOnClock)
        
        // load calendar settings
        reactor.action.onNext(.loadCalendarSetting)
        
        // fetch events
        reactor.action.onNext(.fetchEvents)
        
        // observe events
        reactor.action.onNext(.observeEvents)
        reactor.action.onNext(.observeCalendarSetting)
        reactor.action.onNext(.observeEventsAuthorization)
        
        // fetch weathers
        reactor.action.onNext(.fetchCurrentWeather)
        
        // fetch future weathers
        reactor.action.onNext(.fetchFutureWeather)
        
        // clock state to view
        reactor.state.asObservable().map { $0.currentTime }
            .distinctUntilChanged()
            .bind(to: self.clockLabel!.rx.text)
            .disposed(by: self.disposeBag)

        // date state to view
        reactor.state.asObservable().map { $0.currentDate }
            .distinctUntilChanged()
            .bind(to: self.dateLabel!.rx.text)
            .disposed(by: self.disposeBag)

        // events state to view
        self.tableView!.rx.setDelegate(self).disposed(by: self.disposeBag)
        
        reactor.state.asObservable().map { $0.events }
            .filterNil()
            .filter { _ in !self.tableView!.isEditing }
            //.distinctUntilChanged { $0 == $1 } // 'hide' button keeps sprining back unless this line added
            .bind(to: self.tableView!.rx.items(dataSource: self.dataSource))
            .disposed(by: self.disposeBag)
        
        // for later use: view communication through delegation-like pattern
        let calendarSettingView = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "CalendarSetting") as! EventSettingViewController
        
        // for swipe delete action
        self.tableView!.rx.itemDeleted
            .map { Reactor.Action.deleteEvent($0) }
            .bind(to: reactor.action)
            .disposed(by: self.disposeBag)

        // this is for the time difference between deleting and being hidden
        self.tableView!.rx.itemDeleted
            .subscribe({ item in
                self.view.makeToastActivity(.center)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                    self.view.hideToastActivity()
                    // on ios9 device, isEditing property does not set back to false
                    self.tableView?.setEditing(false, animated: true)
                })
            })
            .disposed(by:self.disposeBag)
        
        // current weather description to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { $0.weather[0].description }
            .bind(to: self.currentDescription!.rx.text)
            .disposed(by: self.disposeBag)

        // current weather icon image to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { UIImage(named: $0.weather[0].icon)!.with(color: UIColor.lightGray) }
            .bind(to: self.currentIcon!.rx.image)
            .disposed(by: self.disposeBag)

        // current weather temperature to view
        reactor.state.asObservable().map { $0.weathers }
            .filterNil()
            .distinctUntilChanged { $0 == $1 }
            .map { String(round($0.main.temp)).split(separator: ".")[0] + "°" }
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
        
        // undo button wired
        self.undoButton!.rx.tap
            .map { Reactor.Action.undoDelete}
            .bind(to: reactor.action)
            .disposed(by: self.disposeBag)
        
        // make toast when undo button tapped
        self.undoButton!.rx.tap
            .subscribe(onNext: {
                let text = "All hidden events are restored now"
                self.view.makeToast(text)
            })
            .disposed(by: self.disposeBag)
        
        // display always-on or when-charging UI logic
        reactor.state.asObservable().map { $0.isDisplayLocked }
            .distinctUntilChanged()
            .filterNil()
            .subscribe( onNext: {
                let imageName = $0 ? "locked" : "unlocked"
                let text = $0 ? "display is set to always on" : "display keeps on only when charging"
                self.displayLockButton!.setImage(UIImage(named: imageName), for: .normal)
                self.insomnia.mode = $0 ? .always : .whenCharging
                self.view.makeToast(text)
            })
            .disposed(by: self.disposeBag)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (_) in
        }) { (_) in
            self.applyOrientations()
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    func applyOrientations() {
        let orient = UIApplication.shared.statusBarOrientation
        
        switch orient {
        case .portrait:
            self.applyPortraitConstraint()
            break
        case .portraitUpsideDown:
            self.applyPortraitConstraint()
            break
        default:
            self.applyLandscapeConstraint()
        }
    }
    
    func applyPortraitConstraint() {
        self.view.addConstraint(clockXPositionPortrait!)
        self.view.addConstraint(currentIconXPositionPortrait!)
        self.view.addConstraint(currentDescriptionWidthPortrait!)
        self.view.addConstraint(weathersWidthPortrait!)
        self.view.addConstraint(weathersXPositionPortrait!)
        self.view.addConstraint(tableWidthPortrait!)
        self.view.addConstraint(tableXPositionPortrait!)
        self.view.addConstraint(tableTopPortrait!)
        
        self.view.removeConstraint(clockXPositionLandscape!)
        self.view.removeConstraint(currentIconXPositionLandscape!)
        self.view.removeConstraint(currentDescriptionWidthLandscape!)
        self.view.removeConstraint(weathersWidthLandscape!)
        self.view.removeConstraint(weathersXPositionLandscape!)
        self.view.removeConstraint(tableWidthLandscape!)
        self.view.removeConstraint(tableXPositionLandscape!)
        self.view.removeConstraint(tableTopLandscape!)
    }
    
    func applyLandscapeConstraint() {
        self.view.addConstraint(clockXPositionLandscape!)
        self.view.addConstraint(currentIconXPositionLandscape!)
        self.view.addConstraint(currentDescriptionWidthLandscape!)
        self.view.addConstraint(weathersWidthLandscape!)
        self.view.addConstraint(weathersXPositionLandscape!)
        self.view.addConstraint(tableWidthLandscape!)
        self.view.addConstraint(tableXPositionLandscape!)
        self.view.addConstraint(tableTopLandscape!)

        self.view.removeConstraint(clockXPositionPortrait!)
        self.view.removeConstraint(currentIconXPositionPortrait!)
        self.view.removeConstraint(currentDescriptionWidthPortrait!)
        self.view.removeConstraint(weathersWidthPortrait!)
        self.view.removeConstraint(weathersXPositionPortrait!)
        self.view.removeConstraint(tableWidthPortrait!)
        self.view.removeConstraint(tableXPositionPortrait!)
        self.view.removeConstraint(tableTopPortrait!)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return
            self.view.traitCollection.horizontalSizeClass == .regular &&
            self.view.traitCollection.verticalSizeClass == .regular
                ? CGSize(width: 80, height: 131) : CGSize(width: 50, height: 82)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return
            self.view.traitCollection.horizontalSizeClass == .regular &&
            self.view.traitCollection.verticalSizeClass == .regular
                ? CGSize(width: 80, height: 131) : CGSize(width: 50, height: 82)
    }
    
}

extension ViewController: UITableViewDelegate {
    // event table view cell height
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return
            self.view.traitCollection.horizontalSizeClass == .regular &&
            self.view.traitCollection.verticalSizeClass == .regular
                ? 160 : 80
    }

    // for delete button style customization
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if isEditing { return .none }
        let deleteButton = UITableViewRowAction(style: .default, title: "HIDE") { (action, indexPath) in
            self.tableView!.dataSource?.tableView!(self.tableView!, commit: .delete, forRowAt: indexPath)
            
        }
        deleteButton.backgroundColor = .gray
        return [deleteButton]
    }
    
    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        tableView.setEditing(true, animated: true)
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

class WeatherHeader: UICollectionViewCell {
    @IBOutlet weak var day: UILabel?
    @IBOutlet weak var weekday: UILabel?
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
