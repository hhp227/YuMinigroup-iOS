//
//  YouTubeRemoteDataSource.swift
//  YuMinigroup
//
//  Android viewmodel.YoutubeSearchViewModel.fetchDataTask(JsonObjectRequest) 대응 — 이 리포는 1차
//  관례대로 VM이 아니라 DataSource+Repository 계층에 네트워킹/파싱을 둔다(SeatRemoteDataSource와 동일
//  경계). 공개 GET, 쿠키/헤더 불필요(스펙 §8) — HttpClient.request를 headers 기본값([:])으로 그대로
//  호출한다.
//
//  URL: `?part=snippet&key={KEY}&q={percent-encoded}&maxResults=50&type=video`. Android는 q를
//  percent-encoding 없이 그대로 이어붙이고 type을 지정하지 않는데(검색어에 &/공백 등이 섞이면 뒤
//  파라미터가 깨지고, 채널 결과가 섞여 들어오면 id.videoId가 없어 파싱 예외가 났다) — 스펙 §2 결함 6
//  수정으로 q는 RFC 3986 unreserved 문자만 남기고 percent-encode하고, type=video를 추가해 채널 결과
//  혼입을 원천 차단한다.
//
//  파싱: JSONDecoder로 중첩 struct(SearchResponse.items[RawItem])를 디코딩한다. RawItem.init(from:)은
//  절대 throw하지 않고 내부적으로 각 필드를 `try?`로 시도해 실패하면 youTubeItem을 nil로 담는다 — 만약
//  대신 상위 UnkeyedDecodingContainer.decode(_:) 자체를 `try?`로 감싸 실패한 원소를 건너뛰려 하면,
//  Foundation의 JSONDecoder 구현이 decode 실패 시 currentIndex를 증가시키지 않아 같은 원소에서 무한
//  루프에 빠진다 — 그래서 원소 각각이 "항상 성공하는" Decodable이 되도록 이렇게 뒤집었다(항목 실패
//  skip을 안전하게 구현하는 방법).
//
//  에러 응답(`{"error":{"message":...}}`)이면 그 메시지로 `.error` 강등(스펙 §8 "유튜브 API 실패(쿼터
//  등): 토스트로 메시지 표시").
//

import Foundation

final class YouTubeRemoteDataSource {
    private static let maxResults = 50

    // Android fetchDataTask(query) 대응. 요청 자체는 페이징이 없다(Android LIMIT=50 그대로).
    func searchVideos(query: String, completion: @escaping (Resource<[YouTubeItem]>) -> Void) {
        completion(.loading)

        let encodedQuery = YouTubeRemoteDataSource.percentEncode(query)
        let urlString = "\(EndPoint.youtubeSearch)?part=snippet&key=\(EndPoint.youtubeApiKey)&q=\(encodedQuery)&maxResults=\(YouTubeRemoteDataSource.maxResults)&type=video"

        HttpClient.request(urlString) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let body):
                completion(YouTubeRemoteDataSource.parse(body))
            }
        }
    }

    // MARK: - URL 인코딩 (스펙 §2 결함 6)

    // RFC 3986 unreserved 문자(ASCII A-Z/a-z/0-9와 -._~)만 리터럴로 나열해 허용 집합을 만든다. 두 가지
    // 함정을 모두 피하기 위해서다:
    //  ① CharacterSet.alphanumerics는 "영숫자"가 아니라 유니코드 문자 범주(Letter/Number) 전체다 —
    //     한글 음절(Hangul Syllable, 카테고리 Lo "Other Letter")도 여기 포함돼 "허용됨"으로 통과한다.
    //     그 결과 한글 검색어가 percent-encoding을 건너뛰고 원문 그대로 URL 문자열에 섞여 들어가고,
    //     URL(string:)이 그 미인코딩 유니코드를 못 읽어 "잘못된 URL"로 요청 자체가 실패한다(주
    //     사용자층인 한국어 검색어에서 사실상 매번 실패하는 리그레션이었다 — 리뷰 Important 1).
    //  ② 그렇다고 CharacterSet.urlQueryAllowed로 바꾸는 것도 오답이다 — 그 집합은 &/=/? 같은 쿼리
    //     예약문자를 "허용"에 포함하므로, 검색어 안에 &가 있으면 다시 미인코딩된 채로 남아 뒤의
    //     maxResults/type 파라미터를 깨뜨리는 원래 결함(스펙 §2 결함 6)이 재발한다.
    // 그래서 ASCII 리터럴 62자(A-Z/a-z/0-9)+-._~ 4자만 못박아 두 함정을 동시에 피한다 — 한글·공백·
    // &/=?는 전부 percent-encoding 대상이 되고, 순수 ASCII 영숫자·구두점만 그대로 남는다.
    private static let queryValueAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func percentEncode(_ query: String) -> String {
        query.addingPercentEncoding(withAllowedCharacters: YouTubeRemoteDataSource.queryValueAllowed) ?? query
    }

    // MARK: - JSON 파싱 (스펙 §6.2)

    private static func parse(_ body: String) -> Resource<[YouTubeItem]> {
        guard let data = body.data(using: .utf8) else {
            return .error("검색 결과를 불러오지 못했습니다.")
        }
        let decoder = JSONDecoder()

        if let response = try? decoder.decode(SearchResponse.self, from: data) {
            return .success(response.items.compactMap { $0.youTubeItem })
        }
        if let errorResponse = try? decoder.decode(ApiErrorResponse.self, from: data) {
            return .error(errorResponse.error.message)
        }
        return .error("검색 결과를 불러오지 못했습니다.")
    }

    private struct ApiErrorResponse: Decodable {
        struct Body: Decodable {
            let message: String
        }
        let error: Body
    }

    private struct SearchResponse: Decodable {
        let items: [RawItem]
    }

    // items[] 원소 하나 — id.videoId / snippet.publishedAt·title·channelTitle / snippet.thumbnails.
    // medium.url을 뽑는다. 파일 헤더 코멘트 참고: 이 init(from:)은 절대 throw하지 않는다(항목 단위
    // 실패를 youTubeItem == nil로 삼켜 배열 디코딩이 멈추지 않게 한다).
    private struct RawItem: Decodable {
        let youTubeItem: YouTubeItem?

        private enum RootKeys: String, CodingKey { case id, snippet }
        private enum IdKeys: String, CodingKey { case videoId }
        private enum SnippetKeys: String, CodingKey { case publishedAt, title, channelTitle, thumbnails }
        private enum ThumbnailsKeys: String, CodingKey { case medium }
        private enum ThumbnailKeys: String, CodingKey { case url }

        init(from decoder: Decoder) throws {
            youTubeItem = RawItem.parse(decoder)
        }

        private static func parse(_ decoder: Decoder) -> YouTubeItem? {
            guard let root = try? decoder.container(keyedBy: RootKeys.self),
                  let idContainer = try? root.nestedContainer(keyedBy: IdKeys.self, forKey: .id),
                  let videoId = try? idContainer.decode(String.self, forKey: .videoId),
                  let snippet = try? root.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet),
                  let publishedAt = try? snippet.decode(String.self, forKey: .publishedAt),
                  let title = try? snippet.decode(String.self, forKey: .title),
                  let channelTitle = try? snippet.decode(String.self, forKey: .channelTitle),
                  let thumbnails = try? snippet.nestedContainer(keyedBy: ThumbnailsKeys.self, forKey: .thumbnails),
                  let medium = try? thumbnails.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .medium),
                  let url = try? medium.decode(String.self, forKey: .url) else {
                return nil
            }
            return YouTubeItem(videoId: videoId, publishedAt: publishedAt, title: title, thumbnail: url, channelTitle: channelTitle)
        }
    }
}
