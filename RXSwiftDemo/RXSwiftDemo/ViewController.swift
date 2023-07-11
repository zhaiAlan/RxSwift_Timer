//
//  ViewController.swift
//  RXSwiftDemo
//
//  Created by zxz on 2023/6/12.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lapBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var labelChrono: UILabel!
    
    let tableHeaderView = UILabel()
    
    let disposeBag = DisposeBag()
    var timer: Observable<Int>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        
        let isRunning = Observable
            .merge([startBtn.rx.tap.map({ return true }), stopBtn.rx.tap.map({ return false })])
            .startWith(false)
            .share(replay: 1, scope: .whileConnected)
        
        isRunning
            .subscribe(onNext: {
                print($0)
            })
            .disposed(by: disposeBag)
        
        let isntRunning = isRunning
            .map({running -> Bool in
                print(running)
                return !running
            })
            .share(replay: 1, scope: .whileConnected)
        
        isRunning
            .bind(to: stopBtn.rx.isEnabled)
            .disposed(by: disposeBag)
        
        isntRunning
            .bind(to: lapBtn.rx.isHidden)
            .disposed(by: disposeBag)
        
        isntRunning
            .bind(to: startBtn.rx.isEnabled)
            .disposed(by: disposeBag)
        
        //create the timer
        timer = Observable<Int>
            .interval(DispatchTimeInterval.milliseconds(100), scheduler: MainScheduler.instance)
            .withLatestFrom(isRunning, resultSelector: {_, running in running})
            .filter({running in running})
            .scan(0, accumulator: {(acc, _) in
                return acc+1
            })
            .startWith(0)
            .share(replay: 1, scope: .whileConnected)
        
        timer
            .subscribe { (msecs) in
                print("\(msecs)00ms")
            }
            .disposed(by: disposeBag)
        
        //wire the chrono
        timer.map(stringFromTimeInterval)
            .bind(to: labelChrono.rx.text)
            .disposed(by: disposeBag)
        
        let lapsSequence = timer
            .sample(lapBtn.rx.tap)
            .map(stringFromTimeInterval)
            .scan([String](), accumulator: { lapTimes, newTime in
                return lapTimes + [newTime]
            })
            .share(replay: 1, scope: .whileConnected)
        
        lapsSequence
            .bind(to: tableView.rx.items(cellIdentifier: "Cell_ID", cellType: UITableViewCell.self)) { (row, element, cell) in
                cell.textLabel?.text = "\(row+1)) \(element)"
            }
            .disposed(by: disposeBag)
        
        //设置 table delegate
        tableView
            .rx.setDelegate(self)
            .disposed(by: disposeBag)
        
        //update the table header
        lapsSequence.map({ laps -> String in
            return "计时\t\(laps.count) 次"
        })
        .startWith("\t没有计时")
        .bind(to: tableHeaderView.rx.text)
        .disposed(by: disposeBag)
        
    }
}

    extension ViewController: UITableViewDelegate {
        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            return tableHeaderView
        }
    }

    func stringFromTimeInterval(_ ms: NSInteger) -> String {
        return String(format: "%0.2d:%0.2d.%0.1d 秒",
                      arguments: [(ms / 600) % 600, (ms % 600 ) / 10, ms % 10])
    }


