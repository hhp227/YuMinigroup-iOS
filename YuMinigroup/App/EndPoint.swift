//
//  EndPoint.swift
//  YuMinigroup
//
//  Android app.EndPoint(interface 상수) 대응 — 1차분 전체 미러. {UID}/{FILE} 치환은
//  URL 문자열 상수 대신 헬퍼 함수(userImage/groupImage)로 대체한다.
//  2차 Task 1(그룹찾기/가입신청중/그룹생성 데이터층)에서 CREATE_GROUP/REGISTER/GROUP_IMAGE_UPDATE/
//  NO_PHOTO_IMAGE를 추가했다. 3차 Task 1(WebViewScreen 공통 컴포넌트)에서 URL_YU_SHUTTLE_BUS를
//  shuttleBus로 추가했다. 나머지 3차 이연 또는 영구 제외 예정 URL(MODIFY/UPDATE_GROUP/GROUP_MEMBER_LIST/
//  SEND_MESSAGE/TIMETABLE/영대소식/도서관/유튜브)은 여전히 YAGNI로 제외.
//

enum EndPoint {
    static let yuPortalLoginURL = "https://portal.yu.ac.kr/sso/login_process.jsp"
    static let baseURL = "http://lms.yu.ac.kr"
    static let loginLMS = baseURL + "/ilos/lo/login_sso.acl"
    static let groupList = baseURL + "/ilos/m/community/share_group_list.acl"
    static let withdrawalGroup = baseURL + "/ilos/community/share_auth_drop_me.acl"
    static let deleteGroup = baseURL + "/ilos/community/share_group_delete.acl"
    static let createGroup = baseURL + "/ilos/community/share_group_insert.acl"
    static let registerGroup = baseURL + "/ilos/community/share_group_register.acl"
    static let groupImageUpdate = baseURL + "/ilos/community/share_group_image_update.acl"
    static let noPhotoImage = baseURL + "/ilos/images/community/share_nophoto.gif"
    static let groupArticleList = baseURL + "/ilos/community/share_list.acl"
    static let writeArticle = baseURL + "/ilos/community/share_insert.acl"
    static let imageUpload = baseURL + "/ilos/tinymce/file_upload_pop.acl"
    static let deleteArticle = baseURL + "/ilos/community/share_delete.acl"
    static let modifyArticle = baseURL + "/ilos/community/share_update.acl"
    static let insertReply = baseURL + "/ilos/community/share_comment_insert.acl"
    static let deleteReply = baseURL + "/ilos/community/share_comment_delete.acl"
    static let modifyReply = baseURL + "/ilos/community/share_comment_update.acl"
    static let memberList = baseURL + "/ilos/community/share_member_list.acl"
    static let getUserImage = baseURL + "/ilos/mp/myinfo_update_photo.acl"
    static let myInfo = baseURL + "/ilos/mp/myinfo_form.acl"
    static let syncProfile = baseURL + "/ilos/mp/myinfo_sync.acl"
    static let profileImagePreview = baseURL + "/ilos/mp/myinfo_file_update.acl"
    static let profileImageUpdate = baseURL + "/ilos/mp/myinfo_insert.acl"
    static let schedule = "https://homep.yu.ac.kr/_app/calendarxml_u.php"
    static let shuttleBus = "https://hcms.yu.ac.kr/main/life/information-on-the-school-bus.do"

    static func userImage(uid: String) -> String {
        baseURL + "/ilos/mp/user_image_view.acl?id=\(uid)&ext=.jpg"
    }
    static func groupImage(file: String) -> String {
        baseURL + "/ilosfiles/club/photo/\(file)"
    }
}
