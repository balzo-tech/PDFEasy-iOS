//
//  ResizableSheetView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/08/23.
//

import SwiftUI

fileprivate struct ResizableSheetViewModifierIsPresented<ViewContent: View>: ViewModifier {
    
    @Binding var isPresented: Bool
    let backgroundColor: Color
    let viewContentBuilder: () -> ViewContent
    
    func body(content: Content) -> some View {
        content
            .sheet(item: self.$item) { unwrappedItem in
                self.viewContentBuilder(unwrappedItem)
                    .background(self.backgroundColor)
                    .modifier(ResizableSheetContentViewModifier())
            }
    }
}

fileprivate struct ResizableSheetViewModifierItem<ViewContent: View, Item: Identifiable>: ViewModifier {
    
    @Binding var item: Item?
    let backgroundColor: Color
    let viewContentBuilder: (Item) -> ViewContent
    
    func body(content: Content) -> some View {
        content
            .sheet(item: self.$item) { unwrappedItem in
                self.viewContentBuilder(unwrappedItem)
                    .background(self.backgroundColor)
                    .modifier(ResizableSheetContentViewModifier())
            }
    }
}

// TODO: Fix missing auto resize on iPad (presentationDetents seems to be ignored on iPad)
fileprivate struct ResizableSheetContentViewModifier: ViewModifier {
    
    @State private var sheetHeight: CGFloat = .zero
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Color.clear.preference(key: InnerHeightPreferenceKey.self, value: geometry.size.height)
                }
            }
            .onPreferenceChange(InnerHeightPreferenceKey.self) { newHeight in
                self.sheetHeight = newHeight
            }
            .presentationDetents([.height(self.sheetHeight)])
    }
}

fileprivate struct InnerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func resizableSheet<ViewContent: View>(isPresented: Binding<Bool>,
                                           backgroundColor: Color,
                                           @ViewBuilder content: @escaping () -> ViewContent) -> some View {
        self.modifier(ResizableSheetViewModifierIsPresented(isPresented: isPresented,
                                                            backgroundColor: backgroundColor,
                                                            viewContentBuilder: content))
    }
    
    func resizableSheet<ViewContent: View, Item: Identifiable>(item: Binding<Item?>,
                                                               backgroundColor: Color,
                                                               @ViewBuilder content: @escaping (Item) -> ViewContent) -> some View {
        self.modifier(ResizableSheetViewModifierItem(item: item,
                                                     backgroundColor: backgroundColor,
                                                     viewContentBuilder: content))
    }
}

struct ResizableSheetView_Previews: PreviewProvider {
    
    private struct ResizableSheetViewTestItem: Identifiable {
        var id: String
        let name: String
    }
    
    static var previews: some View {
        Color.white
            .resizableSheet(isPresented: .constant(true), backgroundColor: .black) {
                VStack {
                    Text("Test Text 1")
                    Spacer().frame(height: 200)
                    Text("Test Text 2")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .previewDisplayName("Resizable Sheet Is Presented")
        Color.white
            .resizableSheet(item: .constant(ResizableSheetViewTestItem(id: "1", name: "Test Element")), backgroundColor: .black) { item in
                VStack {
                    Text("Test Text 1")
                    Spacer().frame(height: 200)
                    Text("Test: \(item.name)")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .previewDisplayName("Resizable Sheet Item")
    }
}
