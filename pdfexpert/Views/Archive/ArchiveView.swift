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
            self.archiveViewModel.refresh()
        }
        .fullScreenCover(isPresented: self.$archiveViewModel.monetizationShow) {
            SubscriptionView(onComplete: { self.archiveViewModel.monetizationShow = false })
        }
        .sheet(item: self.$archiveViewModel.pdfToBeShared) { pdf in
            ActivityViewController(activityItems: [pdf.data!],
                                   thumbnail: pdf.thumbnail)
        }
        .asyncView(asyncOperation: self.$archiveViewModel.asyncItemDelete)
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
                    Button(action: { self.archiveViewModel.shareItem(item: item) }) {
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
                                Text(item.pageCountText)
                                    .font(FontPalette.fontRegular(withSize: 15))
                                    .foregroundColor(ColorPalette.fourthText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            Image(systemName: "square.and.arrow.up")
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
                    .listStyle(.plain)
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
            Button(action: {
                self.archiveViewModel.refresh()
            }) {
                Text("Retry")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .font(FontPalette.fontBold(withSize: 16))
                    .foregroundColor(ColorPalette.primaryText)
                    .contentShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(self.defaultGradientBackground)
            .cornerRadius(10)
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
