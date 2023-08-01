//
//  ArchiveView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import SwiftUI
import Factory

struct ArchiveView: View {
    
    @InjectedObject(\.archiveViewModel) var viewModel
    
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Pdf? = nil
    @State private var importTutorialShow: Bool = false
    
    var body: some View {
        ZStack {
            self.content
            if self.viewModel.isLoading {
                AnyView(self.getLoadingView())
            }
        }
        .background(ColorPalette.primaryBG)
        .onAppear() {
            self.viewModel.onAppear()
        }
        .asyncView(asyncOperation: self.$viewModel.asyncItemDelete)
        .fullScreenCover(isPresented: self.$importTutorialShow) {
            ImportTutorialView()
        }
        .showShareView(coordinator: self.viewModel.pdfShareCoordinator)
    }
    
    var content: some View {
        switch self.viewModel.asyncItems.status {
        case .empty: return AnyView(Spacer())
        case .loading: return AnyView(self.getLoadingView())
        case .data(let items): return AnyView(self.getItemList(items: items))
        case .error: return AnyView(self.getErrorView())
        }
    }
    
    func getItemList(items: [Pdf]) -> some View {
        if items.count > 0 {
            return AnyView(
                List(items) { item in
                    Button(action: { self.viewModel.editItem(item: item) }) {
                        HStack(spacing: 16) {
                            self.getPdfThumbnail(forPdf: item)
                                .frame(width: 86)
                                .cornerRadius(10)
                            VStack(spacing: 0) {
                                Spacer()
                                Text(item.filename)
                                    .font(FontPalette.fontMedium(withSize: 16))
                                    .foregroundColor(ColorPalette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                Spacer().frame(height: 16)
                                HStack(spacing: 16) {
                                    Text(item.pageCountText)
                                        .font(FontPalette.fontMedium(withSize: 15))
                                        .foregroundColor(ColorPalette.fourthText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if item.password != nil {
                                        Image("password_entered")
                                    }
                                    Button(action: { self.viewModel.shareItem(item: item) }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 20).bold())
                                            .foregroundColor(ColorPalette.primaryText)
                                    }
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.trailing, 16)
                        .background(ColorPalette.secondaryBG)
                    }
                    .frame(height: 94)
                    .cornerRadius(10)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.clear))
                    .swipeActions(allowsFullSwipe: false, content: {
                        Button(role: .none, action: {
                            self.itemToDelete = item
                            self.showingDeleteAlert = true
                        }, label: {
                            Image(systemName: "trash")
                        })
                        .tint(Color.red)
                    })
                    .actionDialog(
                        Text("Are you sure?"),
                        isPresented: self.$showingDeleteAlert,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            self.showingDeleteAlert = false
                            withAnimation {
                                if let itemToDelete = self.itemToDelete {
                                    self.viewModel.delete(item: itemToDelete)
                                }
                            }
                        }
                    }
                }
                    // Needed to use a custom background color in case of List with inset list style
                    .scrollContentBackground(.hidden)
                    .listStyle(.inset)
                    .safeAreaInset(edge: .bottom) {
                        Button(action: { self.importTutorialShow = true }) {
                            HStack(spacing: 8) {
                                Image("info")
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                Text("Convert from any file")
                                    .frame(maxHeight: .infinity)
                                    .font(FontPalette.fontMedium(withSize: 18))
                                    .foregroundColor(ColorPalette.primaryText)
                            }
                            .contentShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(self.defaultGradientBackground)
                        .cornerRadius(10)
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 32, trailing: 32))
                    }
            )
        } else {
            return AnyView(self.getEmptyView)
        }
    }
    
    var getEmptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("archive_empty")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("You haven’t converted any files yet")
                .font(FontPalette.fontRegular(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding([.leading, .trailing], 16)
    }
    
    func getLoadingView() -> some View {
        AnimationType.dots.view.background(Color(.black).opacity(0.3))
    }
    
    func getErrorView() -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image("subscription_error")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("Oh nou")
                .font(FontPalette.fontMedium(withSize: 32))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Something went wrong,\nmind trying again?")
                .font(FontPalette.fontRegular(withSize: 15))
                .foregroundColor(ColorPalette.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            self.getDefaultButton(text: "Retry",
                                  onButtonPressed: self.viewModel.refresh)
            Spacer()
        }
        .padding([.leading, .trailing], 16)
    }
    
    func getPdfThumbnail(forPdf pdf: Pdf) -> some View {
        if let thumbnail = pdf.thumbnail {
            return AnyView(
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            )
        } else {
            return AnyView(ColorPalette.secondaryBG)
        }
    }
}

extension Pdf {
    
    var pageCountText: String {
        "\(self.pageCount) pages"
    }
}

struct ArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveView()
    }
}
