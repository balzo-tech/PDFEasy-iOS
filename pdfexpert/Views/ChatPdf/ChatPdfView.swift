//
//  ChatPdfView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import SwiftUI
import Factory

struct ChatPdfView: View {
    
    @StateObject var viewModel: ChatPdfViewModel
    
    @State var typingMessage: String = ""
    @Namespace var bottomID
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading){
                if !self.viewModel.messages.isEmpty {
                    ScrollViewReader { reader in
                        ScrollView(.vertical) {
                            ForEach(self.viewModel.messages.indices, id: \.self){ index in
                                let message = self.viewModel.messages[index]
                                MessageView(message: message)
                            }
                            Text("").id(self.bottomID)
                        }
                        .onAppear{
                            withAnimation{
                                reader.scrollTo(self.bottomID)
                            }
                        }
                        .onChange(of: self.viewModel.messages.count){ _ in
                            withAnimation{
                                reader.scrollTo(self.bottomID)
                            }
                        }
                    }
                } else {
                    VStack{
                        Image(systemName: "ellipses.bubble")
                            .font(.largeTitle)
                        Text("Write your first message!")
                            .font(FontPalette.fontRegular(withSize: 14))
                            .foregroundColor(ColorPalette.primaryText)
                            .padding(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                HStack(alignment: .center){
                    TextField("Type your Message...", text: self.$typingMessage, axis: .vertical)
                        .padding()
                        .font(FontPalette.fontMedium(withSize: 14))
                        .foregroundColor(ColorPalette.primaryText)
                        .lineLimit(3)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    Button {
                        if self.typingMessage != "" {
                            self.viewModel.getResponse(text: self.typingMessage)
                            self.typingMessage = ""
                        }
                    } label: {
                        Image(systemName: self.typingMessage == "" ? "circle" : "paperplane.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(self.typingMessage == "" ? .white.opacity(0.75) : .white)
                            .frame(width: 20, height: 20)
                            .padding()
                    }
                }
                .onDisappear {
                    UIApplication.dismissKeyboard()
                }
                .background(ColorPalette.secondaryBG)
                .cornerRadius(12)
                .padding([.leading, .trailing, .bottom], 10)
                .shadow(color: .black, radius: 0.5)
            }
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Chat")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: { self.dismiss() })
            .onAppear() {
                self.viewModel.onAppear()
            }
            .onDisappear() {
                self.viewModel.onDisappear()
            }
        }
        .background(ColorPalette.primaryBG)
    }
}

struct ChatPdfView_Previews: PreviewProvider {
    
    private static let testChatPdfRef = ChatPdfRef(sourceId: "test_source_id")
    private static let testChatPdfMessage = ChatPdfMessage(role: .assistant,
                                                           type: .text,
                                                           content: "Welcome message")
    private static let testChatPdfInitParams = ChatPdfInitParams(chatPdfRef: testChatPdfRef,
                                                                 introductoryMessage: testChatPdfMessage)
    private static let testParameters = ChatPdfViewModel.Parameters(chatPdfInitParams: Self.testChatPdfInitParams)
    
    static var previews: some View {
        let _ = Container.shared.chatPdfManager.register { ChatPdfManagerMock() }
        ChatPdfView(viewModel: Container.shared.chatPdfViewModel(self.testParameters))
    }
}
