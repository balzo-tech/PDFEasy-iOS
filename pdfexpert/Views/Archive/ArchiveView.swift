//
//  ArchiveView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import SwiftUI
import Factory

struct ArchiveView: View {
    
    @InjectedObject(\.archiveViewModel) var archiveViewModel
    
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Pdf? = nil
    @State private var importTutorialShow: Bool = false
    
    var body: some View {
        ZStack {
            self.content
            if self.archiveViewModel.isLoading {
                AnyView(self.getLoadingView())
            }
        }
        .background(ColorPalette.primaryBG)
        .navigationTitle("File")
        .onAppear() {
            self.archiveViewModel.onAppear()
        }
        .asyncView(asyncOperation: self.$archiveViewModel.asyncItemDelete)
        .fullScreenCover(isPresented: self.$importTutorialShow) {
            ImportTutorialView()
        }
        .sheet(item: self.$archiveViewModel.pdfToBeReviewed) { pdf in
            NavigationStack {
                let inputParameter = PdfViewerViewModel.InputParameter(pdf: pdf,
                                                                       marginsOption: nil,
                                                                       compression: nil)
                PdfViewerView(viewModel: Container.shared.pdfViewerViewModel(inputParameter))
                    .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                        self.archiveViewModel.pdfToBeReviewed = nil
                    })
            }
        }
    }
    
    var content: some View {
        switch self.archiveViewModel.asyncItems.status {
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
                    Button(action: { self.archiveViewModel.reviewItem(item: item) }) {
                        HStack(spacing: 16) {
                            self.getPdfThumbnail(forPdf: item)
                                .frame(width: 86)
                                .cornerRadius(10)
                            VStack(spacing: 0) {
                                Spacer()
                                Text(item.creationDateText)
                                    .font(FontPalette.fontRegular(withSize: 15))
                                    .foregroundColor(ColorPalette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                Spacer().frame(height: 16)
                                HStack(spacing: 16) {
                                    Text(item.pageCountText)
                                        .font(FontPalette.fontRegular(withSize: 15))
                                        .foregroundColor(ColorPalette.fourthText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if item.password != nil {
                                        Image("password_entered")
                                    }
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20).bold())
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
                    .confirmationDialog(
                                Text("Are you sure?"),
                                isPresented: self.$showingDeleteAlert,
                                titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            self.showingDeleteAlert = false
                            withAnimation {
                                if let itemToDelete = self.itemToDelete {
                                    self.archiveViewModel.delete(item: itemToDelete)
                                }
                            }
                        }
                    }
                }
                    .listStyle(.inset)
                    .safeAreaInset(edge: .bottom) {
                        self.getDefaultButton(text: "Convert from any file",
                                              onButtonPressed: { self.importTutorialShow = true })
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
        AnimationType.dots.view.loop().background(Color(.black).opacity(0.3))
    }
    
    func getErrorView() -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image("subscription_error")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("Oh nou")
                .font(FontPalette.fontBold(withSize: 32))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Something went wrong,\nmind trying again?")
                .font(FontPalette.fontRegular(withSize: 15))
                .foregroundColor(ColorPalette.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            self.getDefaultButton(text: "Retry",
                                  onButtonPressed: self.archiveViewModel.refresh)
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
    
    var creationDateText: String {
        var text = "Converted on "
        if let creationDate = self.creationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM-dd-YYYY"
            text += dateFormatter.string(from: creationDate)
        } else {
            text += "-"
        }
        return text
    }
    
    var pageCountText: String {
        var text = "-"
        if let pageCount = self.pageCount {
            text = "\(pageCount)"
        }
        return text + " pages"
    }
}

struct ArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveView()
    }
}
