//
//  CameraView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/03/23.
//

import SwiftUI

struct CameraView: View {
    @StateObject var model: CameraViewModel

    @State var currentZoomFactor: CGFloat = 1.0
    
    @Environment(\.dismiss) var dismiss

    var captureButton: some View {
        Button(action: {
            model.capturePhoto()
        }, label: {
            Circle()
                .foregroundColor(.white)
                .frame(width: 80, height: 80, alignment: .center)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                        .frame(width: 65, height: 65, alignment: .center)
                )
        })
    }

    var flipCameraButton: some View {
        Button(action: {
            model.flipCamera()
        }, label: {
            Circle()
                .foregroundColor(Color.gray.opacity(0.2))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image(systemName: "camera.rotate.fill")
                        .foregroundColor(.white))
        })
    }

    var body: some View {
        NavigationView {
            ZStack {
                GeometryReader { reader in
                    ZStack {
                        Color.black.edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            Button(action: {
                                model.switchFlash()
                            }, label: {
                                Image(systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 20, weight: .medium, design: .default))
                            })
                            .accentColor(model.isFlashOn ? .yellow : .white)
                            
                            CameraPreviewView(session: model.session)
                                .gesture(
                                    DragGesture().onChanged({ (val) in
                                        //  Only accept vertical drag
                                        if abs(val.translation.height) > abs(val.translation.width) {
                                            //  Get the percentage of vertical screen space covered by drag
                                            let percentage: CGFloat = -(val.translation.height / reader.size.height)
                                            //  Calculate new zoom factor
                                            let calc = currentZoomFactor + percentage
                                            //  Limit zoom factor to a maximum of 5x and a minimum of 1x
                                            let zoomFactor: CGFloat = min(max(calc, 1), 5)
                                            //  Store the newly calculated zoom factor
                                            currentZoomFactor = zoomFactor
                                            //  Sets the zoom factor to the capture device session
                                            model.zoom(with: zoomFactor)
                                        }
                                    })
                                )
                                .onAppear {
                                    model.configure()
                                }
                                .alert(isPresented: $model.showAlertError, content: {
                                    let error = self.model.error!
                                    if let confirmText = error.confirmText, let confirmAction = error.confirmAction {
                                        return Alert(title: Text(error.title),
                                                     message: Text(error.message),
                                                     primaryButton: .default(Text(confirmText), action: {
                                            confirmAction()
                                        }),
                                                     secondaryButton: .default(Text(error.dismissText), action: {
                                            model.showAlertError = false
                                        }))
                                    } else {
                                        return Alert(title: Text(error.title),
                                                     message: Text(error.message),
                                                     dismissButton: .default(Text(error.dismissText), action: {
                                            model.showAlertError = false
                                        }))
                                    }
                                })
                                .overlay(
                                    Group {
                                        if model.willCapturePhoto {
                                            Color.black
                                        }
                                    }
                                )
                                .animation(.easeInOut)
                            
                            
                            HStack {
                                Spacer().frame(width: 60)
                                
                                Spacer()
                                
                                captureButton
                                
                                Spacer()
                                
                                flipCameraButton
                                
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                self.getCloseButton(color: .white, onClose: { self.dismiss() })
            }
        }
    }
}

extension CameraError {
    var title: String {
        switch self {
        case .permissionDenied: return "No Permission"
        case .cameraUnavailable: return "Camera unavailable"
        }
    }
    
    var message: String {
        switch self {
        case .permissionDenied: return "You denied permission to save photos your library. Please go to your phone Settings to change your photo gallery permission to save your photo"
        case .cameraUnavailable: return "Unable to access camera"
        }
    }
    
    var dismissText: String {
        switch self {
        case .permissionDenied: return "Cancel"
        case .cameraUnavailable: return "OK"
        }
    }
    
    var confirmText: String? {
        switch self {
        case .permissionDenied: return "Settings"
        case .cameraUnavailable: return nil
        }
    }
    
    var confirmAction: (() -> ())? {
        switch self {
        case .permissionDenied: return {
            if let appSettingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettingsUrl,
                                          options: [:],
                                          completionHandler: nil)
                                      }
        }
        case .cameraUnavailable: return nil
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(model: CameraViewModel(onImageCaptured: { _ in }))
    }
}
