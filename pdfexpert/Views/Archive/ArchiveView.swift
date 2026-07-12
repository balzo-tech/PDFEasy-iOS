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
    @State private var pdfForInfo: Pdf? = nil
    
    var body: some View {
        ZStack {
            self.content
            if self.viewModel.isLoading {
                AnyView(self.getLoadingView())
            }
        }
        .background(ColorPalette.primaryBG)
        .searchable(text: self.$viewModel.searchText, prompt: Text("Search PDFs"))
        .onAppear() {
            self.viewModel.onAppear()
        }
        .asyncView(asyncOperation: self.$viewModel.asyncItemDelete)
        .fullScreenCover(isPresented: self.$importTutorialShow) {
            ImportTutorialView()
        }
        .sheet(item: self.$pdfForInfo) { pdf in
            let inputParameter = PdfMetadataViewModel
                .InputParameter(pdf: pdf,
                                onConfirm: { self.viewModel.updateItem(item: $0) })
            PdfMetadataView(viewModel: Container.shared.pdfMetadataViewModel(inputParameter))
        }
        .showShareView(coordinator: self.viewModel.pdfShareCoordinator)
    }
    
    var content: some View {
        switch self.viewModel.asyncItems.status {
        case .empty: return AnyView(Spacer())
        case .loading: return AnyView(self.getLoadingView())
        case .data(let items): return AnyView(self.getItemList(items: self.viewModel.filteredItems(items)))
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
                            VStack(spacing: 0) {
                                Spacer()
                                Text(item.filename)
                                    .font(forCategory: .body1)
                                    .foregroundColor(ColorPalette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                Spacer().frame(height: 16)
                                HStack(spacing: 16) {
                                    Text(item.pageCountText)
                                        .font(forCategory: .body2)
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
                    .contextMenu {
                        Button(action: { self.pdfForInfo = item }) {
                            Label("Document info", systemImage: "info.circle")
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
                                    .font(forCategory: .button)
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
        } else if !self.viewModel.searchText.isEmpty {
            return AnyView(self.getNoResultsView)
        } else {
            return AnyView(self.getEmptyView)
        }
    }

    var getNoResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .foregroundColor(ColorPalette.fourthText)
            Text("No results")
                .font(forCategory: .largeTitle)
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("No PDF matches your search")
                .font(forCategory: .body1)
                .foregroundColor(ColorPalette.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        }
        .padding([.leading, .trailing], 16)
    }

    var getEmptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("archive_empty")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("You haven’t converted any files yet")
                .font(forCategory: .body1)
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
                .font(forCategory: .largeTitle)
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Something went wrong,\nmind trying again?")
                .font(forCategory: .body1)
                .foregroundColor(ColorPalette.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            self.getDefaultButton(text: "Retry",
                                  onButtonPressed: self.viewModel.refresh)
            Spacer()
        }
        .padding([.leading, .trailing], 16)
    }
    
    @ViewBuilder private func getPdfThumbnail(forPdf pdf: Pdf) -> some View {
        if let thumbnail = pdf.thumbnail {
            Color.clear
                .overlay(Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: 10,
                            style: .continuous))
        } else {
            ColorPalette.secondaryBG
                .cornerRadius(10)
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
