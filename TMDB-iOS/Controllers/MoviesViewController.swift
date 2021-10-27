//
//  MoviesViewController.swift
//  TMDB-iOS
//
//  Created by Amari Duran on 10/9/21.
//

import UIKit
import SimpleNetworking

class MoviesViewController: UIViewController {
	
	enum Section: Int, CaseIterable {
		case nowPlaying, popular, upcoming
		
		var title: String {
			switch self {
			case .nowPlaying: return "Now Playing"
			case .popular: return "Popular"
			case .upcoming: return "Upcoming"
			}
		}
	}
	
	private var dataSource: UICollectionViewDiffableDataSource<Section, MovieViewModel>!
	private var collectionView: UICollectionView!
	
	private var imageObjects = [MovieViewModel]()
	
	// MARK: - View Lifecycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		setupSubviews()
		setupDataSource()
		fetchData()
	}
	
	// MARK: - View Lifecycle Helpers
	
	private func setupSubviews() {
		setupCollectionView()
		setupNavigationBar()
	}
	
	private func setupCollectionView() {
		collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createCollectionViewLayout())
		collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		collectionView.delegate = self
		
		view.addSubview(collectionView)
	}
	
	private func setupNavigationBar() {
		navigationItem.title = "TMDB"
		navigationController?.navigationBar.prefersLargeTitles = true
	}
	
	private func fetchData() {
		var dict: [String: [MovieViewModel]] = [
			Section.popular.title: [],
			Section.nowPlaying.title: [],
			Section.upcoming.title: []
		]
		
		// make network requests then be notified when they're all done. I think this is perfect for
		// something called a semaphor
		
		let dispatchGroup = DispatchGroup()
//		var errors: [APIError] = []
		
		dispatchGroup.enter()
		TMDBMovie.api.send(.popularMovies { result in
			dispatchGroup.leave()
			switch result {
			case .failure(let error):
				break
//				errors.append(error)
			case .success(let data):
				dict[Section.popular.title] = data.results?.map{ MovieViewModel(movie: $0) } ?? []
				dict[Section.nowPlaying.title] = data.results?.map{ MovieViewModel(movie: $0) } ?? []
				dict[Section.upcoming.title] = data.results?.map{ MovieViewModel(movie: $0) } ?? []
			}
		})
		
//		dispatchGroup.enter()
//		TMDBMovie.api.send(.nowPlaying { result in
//			dispatchGroup.leave()
//			switch result {
//			case .failure(let error):
//				errors.append(error)
//			case .success(let data):
//				dict[Section.nowPlaying.title] = data.results?.map{ MovieViewModel(movie: $0) } ?? []
//			}
//		})

//		dispatchGroup.enter()
//		TMDBMovie.api.send(.upcoming { result in
//			dispatchGroup.leave()
//			switch result {
//			case .failure(let error):
//				errors.append(error)
//			case .success(let data):
//				dict[Section.upcoming.title] = data.results?.map{ MovieViewModel(movie: $0) } ?? []
//			}
//		})
		
		dispatchGroup.notify(queue: .main) {
//			if errors != nil {
//				UIAlertController.presentAlert(message: "Unable to fetch all data.", from: self)
//			}
			
			var snapshot = NSDiffableDataSourceSnapshot<Section, MovieViewModel>()
			snapshot.appendSections(Section.allCases)
			snapshot.appendItems(dict[Section.popular.title]!, toSection: .popular)
			snapshot.appendItems(dict[Section.nowPlaying.title]!, toSection: .nowPlaying)
			snapshot.appendItems(dict[Section.upcoming.title]!, toSection: .upcoming)
			self.dataSource.apply(snapshot, animatingDifferences: false)
		}
	}
}

extension MoviesViewController {
	
	private func createCollectionViewLayout() -> UICollectionViewLayout {
		let configuration = UICollectionViewCompositionalLayoutConfiguration()
		configuration.interSectionSpacing = 16
		
		let layout = UICollectionViewCompositionalLayout(
			sectionProvider: { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
				guard Section(rawValue: sectionIndex) != nil else { fatalError("unknown section") }
		
				let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
																							heightDimension: .fractionalHeight(1))
				let item = NSCollectionLayoutItem(layoutSize: itemSize)
				item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
				
				let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(125),
																							 heightDimension: .absolute(165))
				let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
				
				let section = NSCollectionLayoutSection(group: group)
				section.orthogonalScrollingBehavior = .continuous
				section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
				
				let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
																								heightDimension: .estimated(44))
				let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
																																 elementKind: UICollectionView.elementKindSectionHeader,
																																 alignment: .top)
				
				section.boundarySupplementaryItems = [header]
				return section
		}, configuration: configuration)
		
		return layout
	}
	
	private func setupDataSource() {
		let cellRegistration = UICollectionView.CellRegistration<MovieCollectionViewCell, MovieViewModel>(
			handler: { (cell, indexPath, viewModel) -> Void in
				let url = URL(string: "https://image.tmdb.org/t/p/w500\(viewModel.movie.posterPath!)")! as NSURL
				ImageCache.shared.load(url: url) { result in
					switch result {
					case .failure:
						break
					case .success(let image):
						viewModel.posterImage = image
						cell.viewModel = viewModel
					}
				}
			}
		)
		
		dataSource = UICollectionViewDiffableDataSource<Section, MovieViewModel>(
			collectionView: collectionView,
			cellProvider: { (collectionView, indexPath, viewModel) -> UICollectionViewCell? in
				return collectionView.dequeueConfiguredReusableCell(using: cellRegistration,
																														for: indexPath,
																														item: viewModel)
			}
		)
		
		let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderReusableView>(
			elementKind: UICollectionView.elementKindSectionHeader,
			handler: { (supplementaryView, elementKind, indexPath) -> Void in
				let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
				supplementaryView.titleLabel.text = section.title
			}
		)
		
		dataSource.supplementaryViewProvider = { (collectionView, elementKind, indexPath) -> UICollectionReusableView in
			return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration,
																																	 for: indexPath)
		}
	}
	
}

// MARK: - UICollectionViewDelegate
extension MoviesViewController: UICollectionViewDelegate {
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let viewModel = dataSource.itemIdentifier(for: indexPath) else { return }
		
		let detailViewController = MovieDetailViewController(viewModel: viewModel)
		navigationController?.pushViewController(detailViewController, animated: true)
	}
	
}