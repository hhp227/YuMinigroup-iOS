//
//  GroupInfoDialogView.swift
//  YuMinigroup
//
//  Android fragment/GroupInfoFragment(fragment_group_info.xml, 배경 투명 DialogFragment) 대응 —
//  그룹찾기 셀 탭 시 뜨는 중앙 카드. UserDialogView와 달리 시스템 .sheet가 아니라 부모(FindGroupView)가
//  ZStack 오버레이 + 딤 배경으로 직접 띄운다(스펙 §4.2 "커스텀 중앙 다이얼로그").
//
//  레이아웃은 Android RelativeLayout 순서 그대로: 이미지(200pt, centerCrop) 하단에 이름 라벨이
//  겹쳐지고(#77000000 배경·흰 글씨 18sp), 그 아래 설명(16sp, 최대 6줄)+info(13sp), 1px 구분선,
//  버튼 2개(가입신청|신청취소 / 닫기) — 버튼 쌍은 UserDialogView.actionBar 관례(HStack+Divider) 그대로.
//
//  처리 중(isProcessing)에는 두 버튼을 모두 비활성화한다 — Android XML은 버튼을 막지 않지만, 요청이
//  날아간 채로 다이얼로그가 닫히면(닫기 버튼) 나중에 도착하는 응답이 이미 화면에서 사라진
//  ViewModel(그래도 살아있는 참조)에 조용히 반영되는 어색한 상태가 되므로 막는다.
//
//  onChange(of: state.completed)는 CreateArticleView가 state.resultArticle을 관찰하는 것과 같은
//  관례 — nil 아니면 부모(FindGroupView)에게 완료를 알린다.
//
//  리뷰 수정(Finding 1): 이 뷰 자신에 .toast(message: $viewModel.state.message)를 걸었더니
//  ToastModifier가 "content.overlay(alignment: .bottom)"이라 이 카드(VStack) 자신의 하단 —
//  즉 액션 버튼 바로 위 — 에 떴다(화면 하단이 아니라 카드 하단). 다이얼로그는 부모가 가운데에
//  padding을 줘서 띄우는 작은 카드라 "화면 하단" 토스트 관례와 어긋난다. 그래서 이 뷰는 더 이상
//  자신의 message를 직접 그리지 않고, onMessage(String) 콜백으로 부모에게 넘긴다 — 부모
//  (FindGroupView)가 이미 화면 최상위에 갖고 있는 자기 자신의 .toast 표면에 그대로 실어 화면
//  하단에 뜨게 한다(GroupInfoViewModel.swift 헤더 코멘트 참고). 실패 시에는 completed가 nil로
//  남아 다이얼로그가 계속 열려 있으므로, 메시지만 화면 하단에 뜨고 다이얼로그는 그대로 보인다 —
//  브리프가 요구한 동작 그대로다.
//

import SwiftUI

struct GroupInfoDialogView: View {
    @ObservedObject var viewModel: GroupInfoViewModel
    let onClose: () -> Void
    let onMessage: (String) -> Void
    let onCompleted: (GroupInfoViewModel.ButtonType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            infoRow
            Divider()
            actionBar
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(6)
        .onChange(of: viewModel.state.message) { message in
            if let message = message {
                onMessage(message)
            }
        }
        .onChange(of: viewModel.state.completed) { completed in
            if let completed = completed {
                onCompleted(completed)
            }
        }
    }

    // Android iv_group_image(centerCrop) + tv_name(#77000000 배경, 흰 글씨 18sp, singleLine) 대응.
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(urlString: viewModel.group.image)
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()

            Text(viewModel.group.name)
                .font(.system(size: 18))
                .foregroundColorCompat(Color.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.47))
        }
    }

    // Android tv_desciption(16sp, maxLines 6) + tv_info(13sp) 대응.
    private var infoRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description = viewModel.group.description_, !description.isEmpty {
                Text(description)
                    .font(.system(size: 16))
                    .lineLimit(6)
            }
            if let info = viewModel.group.info, !info.isEmpty {
                Text(info)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Android b_request(가입신청/신청취소)/b_close 대응 — UserDialogView.actionBar 관례.
    private var actionBar: some View {
        HStack(spacing: 0) {
            Button(action: { viewModel.sendRequest() }) {
                Group {
                    if viewModel.state.isProcessing {
                        ProgressView()
                    } else {
                        Text(viewModel.buttonType == .request ? "가입신청" : "신청취소")
                            .font(.system(size: 14))
                            .foregroundColorCompat(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .disabled(viewModel.state.isProcessing)

            Divider()

            Button(action: onClose) {
                Text("닫기")
                    .font(.system(size: 14))
                    .foregroundColorCompat(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(viewModel.state.isProcessing)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
