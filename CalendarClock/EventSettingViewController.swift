//
//  EventSettingViewController.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-03-21.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation
import ReactorKit
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional

class EventSettingViewController: UIViewController, StoryboardView {
    typealias Reactor = EventSettingViewReactor
    var disposeBag = DisposeBag()
    
    // event setting cell and header setup
    let dataSource = RxTableViewSectionedReloadDataSource<SectionedEventSettings>(
        configureCell: { dataSource, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "CalendarCell", for: indexPath) as! EventSettingCell
            cell.name!.text = "\(item.name)"
            cell.accessoryType = item.isSelected ? .checkmark : .none
            return cell
        },
        titleForHeaderInSection: { dataSource, index in
            let section = dataSource[index]
            return section.header
        }
    )
    
    @IBOutlet weak var tableView: UITableView?
    
    // hide status bar for aestheic reason
    override open var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func bind(reactor: Reactor) {
        // fetch calendars
        reactor.action.onNext(.fetchCalendars)
        
        // events state to view
        self.tableView!.rx.setDelegate(self).disposed(by: self.disposeBag)
        
        reactor.state.asObservable().map { $0.calendars }
            .filterNil()
            //.distinctUntilChanged { $0 == $1 }
            .bind(to: self.tableView!.rx.items(dataSource: self.dataSource))
            .disposed(by: self.disposeBag)
        
        self.tableView!.rx.itemSelected.asObservable()
            .map { Reactor.Action.saveChanges(($0.section, $0.row)) }
            .bind(to: reactor.action)
            .disposed(by: self.disposeBag)

    }
    
}

extension EventSettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
}

// Event table view cell
class EventSettingCell: UITableViewCell {
    @IBOutlet weak var name: UILabel?
}

class EventSettingSection: UITableViewCell {
    @IBOutlet weak var title: UILabel?
}
