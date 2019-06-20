//
//  Scanner.swift
//  ScannerSample
//
//  Created by 하윤 on 20/06/2019.
//  Copyright © 2019 Supa HaYun. All rights reserved.
//

import UIKit
import AVFoundation

import RxSwift
import RxCocoa

/// 디바이스가 스캐너 기능을 할 수 있도록 도와주는 퍼사드 패턴의 클래스
///
/// Scanner 클래스는 OverlayView를 소유하고 있습니다.
/// 카메라에 비춰지는 화면의 구성과 스캔 영역을 바꾸고 싶으시면
/// OverlayView 클래스와 OverlayView.xib를 수정하세요.
class Scanner {
    
    /// 카메라의 입력과 출력을 연결해주는 세션
    private var session: AVCaptureSession?
    /// 카메라를 통해 비춰지는 화면을 담당하는 레이어
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    let disposeBag = DisposeBag()
    /// 성공적으로 스캔하였을 때 스캔된 코드를 방출해주는 PublishSubject
    private var rx_scanSucceed = PublishSubject<String>()
    
    deinit {
        let fileName = #file
        let funcName = #function
        let line = #line
        print("[\(Date().description)] [\(fileName)] [\(funcName)][Line \(line)]")
    }
    
    /// Scanner의 생성자
    ///
    /// - Parameters:
    ///   - delegate: Scanner의 사용자가 스캔 결과를 받을 수 있는 Delegate
    ///   - view: Scanner 화면의 영역이 될 UIView
    ///   - rx_scanSucceed: 스캔 성공 시 코드를 방출하는 PublishSubject
    ///   - rx_impossibleScan: 스캔이 불가능할 경우 오류 메세지를 방출하는 PublishSubject
    init(delegate: AVCaptureMetadataOutputObjectsDelegate,
         view: UIView,
         rx_scanSucceed: PublishSubject<String>,
         rx_impossibleScan: PublishSubject<String>) {
        
        
        guard let captureDevice = createCaptureDevice(),
            let deviceInput = createDeviceInput(captureDevice: captureDevice),
            let metadataOutput = createMetadataOutput(delegate: delegate),
            let captureSession = createCaptureSession(deviceInput: deviceInput, metadataOutput: metadataOutput)
            else {
                
                rx_impossibleScan.onNext("스캔이 불가능한 디바이스가 입니다.")
                return
        }
        
        // 세션과 연결되어야지 가능한 스캔타입 판가름 가능
        metadataOutput.metadataObjectTypes = self.getAvailableMetadataObjects(output: metadataOutput)
        
        self.session = captureSession
        self.previewLayer = createPreviewLayer(withCaptureSession: captureSession, view: view)
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        
        initOverlayView(superView: view,
                        previewLayer: self.previewLayer!,
                        metadataOutput: metadataOutput,
                        rx_impossibleScan: rx_impossibleScan)
        
        // Rx 바인딩
        self.rx_scanSucceed
            .bind(to: rx_scanSucceed)
            .disposed(by: self.disposeBag)
    }
    
    // 1
    /// AVCaptureDevice를 초기화한 후 반환해주는 메서드
    ///
    /// - Returns: AVCaptureDevice를 반환(초기화에 실패하면 nil 반환)
    private func createCaptureDevice() -> AVCaptureDevice? {
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return nil
        }
        
        do {
            try captureDevice.lockForConfiguration()
            if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                captureDevice.focusMode = .continuousAutoFocus
            }
            if captureDevice.isAutoFocusRangeRestrictionSupported {
                captureDevice.autoFocusRangeRestriction = .near
            }
            captureDevice.unlockForConfiguration()
            
        } catch {
            print("Error locking for configuration, \(error)")
            return nil
        }
        
        return captureDevice
    }
    
    // 2
    /// AVCaptureDeviceInput을 초기화한 후 반환해주는 메서드
    ///
    /// - Parameter captureDevice: 입력받을 AVCaptureDevice
    /// - Returns: AVCaptureDeviceInput를 반환(초기화에 실패하면 nil 반환)
    private func createDeviceInput(captureDevice: AVCaptureDevice) -> AVCaptureDeviceInput? {
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            return deviceInput
            
        } catch {
            
            return nil
        }
    }
    
    // 3
    /// AVCaptureMetadataOutput을 초기화한 후 반환해주는 메서드
    ///
    /// - Parameter delegate: 스캔 결과 값을 받을 Delegate
    /// - Returns: delegate가 세팅된 AVCaptureMetadataOutput를 반환
    private func createMetadataOutput(delegate: AVCaptureMetadataOutputObjectsDelegate) -> AVCaptureMetadataOutput? {
        
        let metadataOutput = AVCaptureMetadataOutput()
        metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        
        return metadataOutput
    }
    
    // 4
    /// 특정 입력(AVCaptureDeviceInput)과 출력(AVCaptureMetadataOutput)을
    /// AVCaptureSession으로 연결 후 그 AVCaptureSession을 반환
    ///
    /// - Parameters:
    ///   - deviceInput: 카메라 기능을 이용하여 스캔 하려는 AVCaptureDeviceInput
    ///   - metadataOutput: 스캔의 메타데이터 다루는 AVCaptureMetadataOutput
    /// - Returns: AVCaptureSession을 반환(세션 초기화에 실패하면 nil 반환)
    private func createCaptureSession(deviceInput: AVCaptureDeviceInput, metadataOutput: AVCaptureMetadataOutput) -> AVCaptureSession? {
        
        let captureSession = AVCaptureSession()
        
        captureSession.beginConfiguration()
        guard captureSession.canAddInput(deviceInput), captureSession.canAddOutput(metadataOutput) else {
            captureSession.commitConfiguration()
            return nil
        }
        captureSession.addInput(deviceInput)
        captureSession.addOutput(metadataOutput)
        
        captureSession.commitConfiguration()
        
        return captureSession
    }
    
    // 5
    /// 카메라에 비춰지는 화면이 표시될 레이어를 초기화 후 반환해주는 메서드
    ///
    /// - Parameters:
    ///   - captureSession: 스캔 입출력이 연결된 세션
    ///   - view: 레이어가 깔리게 될 UIView
    /// - Returns: 카메라 화면이 표시될 레이어를 반환
    private func createPreviewLayer(withCaptureSession captureSession: AVCaptureSession, view: UIView) -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }
    
    // 스캔영역 지정
    /// 오버레이 뷰를 초기화 해주는 메서드
    ///
    /// OverlayView 클래스와 OverlayView.xib에 종속적인 메서드입니다.
    /// 이 두 개의 요소가 없다면 정상적인 초기화가 불가능합니다.
    ///
    /// - Parameters:
    ///   - superView: 오버레이 뷰의 SuperView(오버레이 뷰의 크기는 SuperView와 동일해집니다.)
    ///   - previewLayer: 카메라의 화면이 비춰지는 레이어
    ///   - metadataOutput: 스캔의 메타데이터 다루는 AVCaptureMetadataOutput
    ///   - rx_impossibleScan: 오버레이 뷰 초기화에 실패했을 때 오류 메세지를 방출하는 PublishSubject
    private func initOverlayView(superView: UIView,
                                 previewLayer: AVCaptureVideoPreviewLayer,
                                 metadataOutput: AVCaptureMetadataOutput,
                                 rx_impossibleScan: PublishSubject<String>) {
        
        guard let view_overlay = Bundle.main.loadNibNamed("OverlayView", owner: superView, options: nil)?.first as? OverlayView else {
            rx_impossibleScan.onNext("오버레이뷰 생성에 실패하였습니다.")
            return
        }
        
        view_overlay.translatesAutoresizingMaskIntoConstraints = false
        superView.addSubview(view_overlay)
        view_overlay.topAnchor.constraint(equalTo: superView.topAnchor).isActive = true
        view_overlay.bottomAnchor.constraint(equalTo: superView.bottomAnchor).isActive = true
        view_overlay.leadingAnchor.constraint(equalTo: superView.leadingAnchor).isActive = true
        view_overlay.trailingAnchor.constraint(equalTo: superView.trailingAnchor).isActive = true
        
        view_overlay.setRectOfInterest(previewLayer: previewLayer, metadataOutput: metadataOutput)
    }
    
    /// 현재 디바이스가 스캔이 가능한 코드의 타입들을 반환해주는 메서드
    ///
    /// - Parameter output: 스캔의 메타데이터 다루는 AVCaptureMetadataOutput
    /// - Returns: 스캔이 가능한 코드의 타입들
    private func getAvailableMetadataObjects(output: AVCaptureMetadataOutput) -> [AVMetadataObject.ObjectType] {
        let metaObjectTypes: [AVMetadataObject.ObjectType] = [
            .aztec,
            .code128,
            .code39,
            .code39Mod43,
            .code93,
            .ean13,
            .ean8,
            .pdf417,
            .qr,
            .upce
        ]
        
        var supportedMetadataTypes: [AVMetadataObject.ObjectType] = []
        
        output.availableMetadataObjectTypes.forEach { availableMetadataObjectType in
            
            if metaObjectTypes.contains(availableMetadataObjectType) {
                supportedMetadataTypes.append(availableMetadataObjectType)
            }
        }
        
        return supportedMetadataTypes
    }
    
    /// 스캔 기능을 시작하는 메서드
    func requestCaptureSessionStartRunning() {
        guard let captureSession = self.session else {
            return
        }
        
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    /// 스캔 기능을 종료하는 메서드
    func requestCaptureSessionStopRunning() {
        guard let captureSession = self.session else {
            return
        }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    /// AVCaptureMetadataOutputObjectsDelegate의 같은 형태의 메서드
    ///
    /// 스캔 결과에 대한 처리를 Scanner 클래스에게 위임하고 싶다면
    /// AVCaptureMetadataOutputObjectsDelegate의 오버라이드 메서드
    /// metadataOutput(AVCaptureMetadataOutput:[AVMetadataObject]:AVCaptureConnection:)에서
    /// 이 메서드를 호출하여 주세요.
    ///
    /// - Parameters:
    ///   - output: 스캔의 메타데이터 다루는 AVCaptureMetadataOutput
    ///   - metadataObjects: 스캔 결과 메타데이터들을 담고 있는 객체들
    ///   - connection: AVCaptureConnection 참조
    func scannerDelegate(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        self.requestCaptureSessionStopRunning()
        
        guard let metadataObject = metadataObjects.first,
            let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
            let stringValue = readableObject.stringValue else {
                return
        }
        
        self.rx_scanSucceed.onNext(stringValue)
    }
}
