//
//  SearchBarView.swift
//  HUDrive
//

import SwiftUI
import MapKit
import Combine

struct SearchBarView: View {
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var locationManager: LocationManager
    
    @StateObject private var searchCompleter = SearchCompleterManager()
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                TextField("Search destination", text: $searchText)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .tint(.cyan)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, newValue in
                        searchCompleter.search(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchCompleter.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Results list
            if !searchCompleter.results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchCompleter.results, id: \.self) { result in
                            Button {
                                selectResult(result)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.cyan.opacity(0.8))
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.leading, 56)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            if navigationManager.isCalculatingRoute {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Calculating route...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 16)
            }
            
            if let error = navigationManager.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }
    
    private func selectResult(_ result: MKLocalSearchCompletion) {
        // Resolve the completion to a map item
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else { return }
            
            DispatchQueue.main.async {
                searchText = ""
                searchCompleter.results = []
                isSearchFieldFocused = false
                onDismiss()
                navigationManager.startNavigation(to: mapItem)
            }
        }
    }
}

// MARK: - Search Completer Manager

class SearchCompleterManager: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    @Published var results: [MKLocalSearchCompletion] = []
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func search(query: String) {
        if query.isEmpty {
            results = []
            return
        }
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}
