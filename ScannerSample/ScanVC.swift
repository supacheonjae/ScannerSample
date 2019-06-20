//
//  ScanVC.swift
//  ScannerSample
//
//  Created by 하윤 on 20/06/2019.
//  Copyright © 2019 Supa HaYun. All rights reserved.
//

import UIKit
import AVFoundation

import RxSwift
import RxCocoa

class ScanVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    let disposeBag = DisposeBag()
    
    /// 스캔용 컨테이너 뷰
    @IBOutlet weak var view_scanContainer: UIView!

    /// 스캐너
    private var scanner: Scanner?
    
    /// 스캔이 성공했을 때 코드값을 방출하는 PublishSubject
    private var rx_scanSucceed = PublishSubject<String>()
    /// 스캔이 불가능한 환경일 때 오류 메세지를 방출하는 PublishSubject
    private var rx_impossibleScan = PublishSubject<String>()
    
    deinit {
        // 자동 꺼짐 기능 다시 켬
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Scanner 클래스 초기화 시 전달할 view_scanContainer의 모든 제약조건이
        // 올바르게 적용된 후 전달할 수 있도록 self.view.layoutIfNeeded() 호출
        self.view.layoutIfNeeded()
        
        // Rx 세팅
        setupRx()
        
        // 스캐너 초기화(이니셜라이저 매개변수로 rx 변수들이 들어가기 때문에 Rx 세팅 먼저 함)
        scanner = Scanner(delegate: self,
                          view: view_scanContainer,
                          rx_scanSucceed: rx_scanSucceed,
                          rx_impossibleScan: rx_impossibleScan)
        
        // 자동 꺼짐 방지
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    /// 기본적인 Rx 세팅
    private func setupRx() {
        // 스캔이 불가능한 디바이스일 때
        rx_impossibleScan
            .subscribe(onNext: { errMsg in
                print("오류: \(errMsg)")
            })
            .disposed(by: disposeBag)
        
        // Scan Code Test
        rx_scanSucceed
            .subscribe(onNext: { (code: String) in
                print("code -> \(code)")
            })
            .disposed(by: disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !view_scanContainer.isHidden {
            scanner?.requestCaptureSessionStartRunning()
        }
    }

    // MARK: - Scanning Delegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        self.scanner?.scannerDelegate(output, didOutput: metadataObjects, from: connection)
    }
}

