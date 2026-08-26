//
//  URLs.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/04.
//  Copyright © 2021 홍희표. All rights reserved.
//

let BASE_URL = "http://hong227.dothome.co.kr/hong227/v1"
let URL_REGISTER = "\(BASE_URL)/register"
let URL_LOGIN = "\(BASE_URL)/login"
let URL_PROFILE_EDIT = "\(BASE_URL)/profile"
let URL_POST = "\(BASE_URL)/post"
let URL_POSTS = "\(BASE_URL)/posts?group_id={GROUP_ID}&offset={OFFSET}&load_size={LOAD_SIZE}"
let URL_USER_POSTS = "\(BASE_URL)/posts/?offset={OFFSET}"
let URL_POST_LIKE = "\(BASE_URL)/like/{POST_ID}"
let URL_POST_IMAGE = "\(BASE_URL)/image"
let URL_POST_IMAGE_DELETE = "\(BASE_URL)/images"
let URL_POST_IMAGE_PATH = "\(BASE_URL)/php/Images/"
let URL_REPLYS = "\(BASE_URL)/replys/{POST_ID}"
let URL_REPLY = "\(BASE_URL)/replys/post/{REPLY_ID}" // 댓글 url

let URL_USER_PROFILE_IMAGE = "\(BASE_URL)/php/ProfileImages/"

let URL_GROUP = "\(BASE_URL)/group"
let URL_GROUPS = "\(BASE_URL)/groups?offset={OFFSET}"
let URL_USER_GROUP = "\(BASE_URL)/user_groups?offset={OFFSET}"
let URL_GROUP_IMAGE_PATH = "\(BASE_URL)/php/GroupImages/"
