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

class ViewController: UIViewController, StoryboardView {
    typealias Reactor = ViewReactor
    var disposeBag = DisposeBag()
    let dataSource = RxTableViewSectionedReloadDataSource<SectionedEvents>(configureCell: { dataSource, tableView, indexPath, item in
        print(item)
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "Item \(item.title) - \(item.startDate) : \(item.endDate)"
        return cell
    })

    @IBOutlet weak var clockLabel: UILabel?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var textView: UITextView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    func bind(reactor: Reactor) {
        // start clock
        reactor.action.onNext(.startClicking)
        
        // fetch events
        reactor.action.onNext(.fetchEvents)
        
        // clock state to view
        reactor.state.asObservable().map { $0.currentTime }
            .distinctUntilChanged()
            .bind(to: self.clockLabel!.rx.text)
            .disposed(by: self.disposeBag)
        
        // events state to view
        self.tableView!.rx.setDelegate(self).disposed(by: self.disposeBag)
        
        reactor.state.asObservable().map { $0.events }
            .distinctUntilChanged { $0 == $1 }
            .bind(to: self.tableView!.rx.items(dataSource: self.dataSource))
            .disposed(by: self.disposeBag)
    }

}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
}

struct SectionedEvents: Equatable {
    var header: String
    var items: [Item]
    
    static func ==(lhs: SectionedEvents, rhs: SectionedEvents) -> Bool {
        return lhs.header == rhs.header && lhs.items == rhs.items
    }
}

extension SectionedEvents: SectionModelType {
    typealias Item = CustomEvent
    
    init(original: SectionedEvents, items: [Item]) {
        self = original
        self.items = items
    }
}

extension ObservableType where E: Sequence, E.Iterator.Element: Equatable {
    func distinctUntilChanged() -> Observable<E> {
        return distinctUntilChanged { (lhs, rhs) -> Bool in
            return Array(lhs) == Array(rhs)
        }
    }
}
