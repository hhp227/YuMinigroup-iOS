//
//  PictureViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.PictureViewModel(SavedStateHandle의 "images"/"position") 대응 — 이미지 뷰어의
//  전체 URL 목록 + 현재 페이지 인덱스. Android는 PicturePagerAdapter.submitList(imageList)와
//  ViewPager.OnPageChangeListener가 각각 목록/포지션을 밀어 넣지만, 이 포팅은 둘 다 생성 시점에
//  ArticleView가 확정해 넘겨준 값(article.images 전체 + 탭한 인덱스)이라 그 이후로 목록이 바뀔 일이
//  없으므로 SavedStateHandle 상당 없이 단순 @Published 상태로 충분하다.
//

import Foundation

final class PictureViewModel: ObservableObject {
    struct State {
        var images: [String]
        var index: Int
    }

    @Published var state: State

    init(images: [String], initialIndex: Int) {
        state = State(images: images, index: initialIndex)
    }
}
