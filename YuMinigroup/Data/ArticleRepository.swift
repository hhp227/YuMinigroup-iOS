//
//  ArticleRepository.swift
//  YuMinigroup
//
//  ArticleRemoteDataSource를 그대로 위임하는 순수 패스스루 — GroupRepository.swift/UserRepository.swift와
//  동일한 경계 계층. stopRequestMore는 ArticleRemoteDataSource가 마지막 fetchArticles(offset:) 호출
//  이후 갱신한 값을 그대로 읽어 넘긴다(Android ArticleRepository.isStopRequestMore() 대응).
//
//  fetchArticle(articleId:completion:)은 Task 16이 추가한 상세 조회 패스스루 — ArticleViewModel도
//  Tab1ViewModel/Tab3ViewModel/Tab4ViewModel과 같은 원칙으로 RemoteDataSource를 직접 참조하지 않고
//  이 Repository를 거친다(브리프의 "Modify" 목록엔 이 파일이 빠져 있지만, 그 목록은 아마 누락이다 —
//  이 파일 자체가 "순수 패스스루" 경계라 새 RemoteDataSource 메소드가 생기면 항상 함께 넓혀야 한다).
//
//  addArticle/setArticle/uploadImage는 Task 17이 같은 원칙으로 추가한 패스스루다 — CreateArticleViewModel도
//  ArticleRemoteDataSource를 직접 참조하지 않는다.
//

import UIKit

final class ArticleRepository {
    private let remote: ArticleRemoteDataSource

    init(groupId: String, groupKey: String?) {
        remote = ArticleRemoteDataSource(groupId: groupId, groupKey: groupKey)
    }

    var stopRequestMore: Bool {
        remote.stopRequestMore
    }

    func fetchArticles(offset: Int, completion: @escaping (Resource<[ArticleItem]>) -> Void) {
        remote.fetchArticles(offset: offset, completion: completion)
    }

    func deleteArticle(articleId: String, articleKey: String?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.deleteArticle(articleId: articleId, articleKey: articleKey, completion: completion)
    }

    func fetchArticle(articleId: String, completion: @escaping (Resource<ArticleItem>) -> Void) {
        remote.fetchArticle(articleId: articleId, completion: completion)
    }

    func addArticle(title: String, content: String, imageUrls: [String], youtube: YouTubeItem?, completion: @escaping (Resource<ArticleItem>) -> Void) {
        remote.addArticle(title: title, content: content, imageUrls: imageUrls, youtube: youtube, completion: completion)
    }

    func setArticle(articleId: String, key: String?, title: String, content: String, imageUrls: [String], youtube: YouTubeItem?, completion: @escaping (Resource<ArticleItem>) -> Void) {
        remote.setArticle(articleId: articleId, key: key, title: title, content: content, imageUrls: imageUrls, youtube: youtube, completion: completion)
    }

    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        remote.uploadImage(image, completion: completion)
    }
}
