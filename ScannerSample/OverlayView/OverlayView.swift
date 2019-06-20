//
//  OverlayView.swift
//  ScannerSample
//
//  Created by 하윤 on 20/06/2019.
//  Copyright © 2019 Supa HaYun. All rights reserved.
//

import UIKit
import AVFoundation

import RxSwift

/// 스캐너 오버레이 전용 뷰
///
/// 이 클래스를 생성하는 부분 사이즈 지정 또는 제약조건 추가가
/// 이루어져야 합니다.
class OverlayView: UIView {
    
    /// 스캔 관심 영역
    @IBOutlet weak var view_interest: UIView!
    
    /// 카메라 화면 레이어
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// 스캔 메타데이터 출력 전담 객체
    private var metadataOutput: AVCaptureMetadataOutput?
    
    let disposeBag = DisposeBag()
    
    override func draw(_ rect: CGRect) {
        
        guard let view_interest = view_interest,
            let previewLayer = previewLayer,
            let metadataOutput = metadataOutput else {
                return
        }
        
        UIColor.clear.setFill()
        UIRectFill(view_interest.frame)
        
        let rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: view_interest.frame) // MetadataOutput 전용 Rect로 변경
        metadataOutput.rectOfInterest = rectOfInterest
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    /// 관심 영역 설정
    ///
    /// 실제로 스캔 관심 영역을 설정하는 코드는 draw() 코드 안에 있습니다.
    /// 이 메서드는 관심 영역 설정에 필요한 프로퍼티 값 할당과 draw() 호출만 해줄 뿐입니다.
    ///
    /// - Parameters:
    ///   - previewLayer: 카메라 화면 레이어
    ///   - metadataOutput: 스캔 메타데이터 출력 전담 객체
    func setRectOfInterest(previewLayer: AVCaptureVideoPreviewLayer, metadataOutput: AVCaptureMetadataOutput) {
        
        self.previewLayer = previewLayer
        self.metadataOutput = metadataOutput
        self.setNeedsDisplay()
    }
}
