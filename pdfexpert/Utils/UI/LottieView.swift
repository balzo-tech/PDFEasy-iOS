//
//  LottieView.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let animationView = LottieAnimationView()
    var filename = "loading"
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        
        let animation = LottieAnimation.named(filename)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
    
    func loop(autoReverse: Bool = false) -> some UIViewRepresentable {
        let view = self
        view.animationView.loopMode = autoReverse ? .autoReverse : .loop
        return view
    }
    
//    func setValues() {
//        print(animationView.logHierarchyKeypaths())
//        let keypath = AnimationKeypath(keys: ["**", "Fill 1", "**", "Color"])
//        let colorProvider = ColorValueProvider(UIColor.green.lottieColorValue)
//        animationView.setValueProvider(colorProvider, keypath: keypath)
//    }
}

struct LottieView_Previews: PreviewProvider {
    static var previews: some View {
        LottieView()
    }
}
