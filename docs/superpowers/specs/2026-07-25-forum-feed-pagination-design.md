# Forum Feed Pagination Design

## Muc tieu

Giam so luong truy van va du lieu tai cho moi trang Forum. Feed chi tai du
thong tin de hien thi bai viet; binh luan chi duoc tai khi nguoi dung mo trang
chi tiet bai viet.

## Pham vi

- Toi uu hai feed `For you` va `Following`.
- Phan trang bai viet bang cursor on dinh.
- Phan trang binh luan rieng trong `ThreadPage`.
- Giu nguyen cac hanh vi like, bookmark, follow, report, block, reply, edit va
  delete hien co.
- Khong thay doi bo cuc Forum ngoai cac trang thai loading/load-more cua binh
  luan.

## Kien truc

Flutter goi truc tiep hai PostgreSQL RPC thong qua Supabase:

1. `forum_feed_page` tong hop bai viet, tac gia, media, cac bo dem va trang thai
   tuong tac cua nguoi dung dang dang nhap.
2. `forum_comments_page` tai binh luan cua mot bai viet theo tung trang.

Database thuc hien join va aggregate tai noi du lieu duoc luu tru. Flutter chi
parse ket qua va quan ly trang thai UI, thay vi thuc hien nhieu truy van lien
tiep roi ghep du lieu trong bo nho.

## Contract `forum_feed_page`

### Dau vao

- `p_feed`: `for_you` hoac `following`.
- `p_limit`: so bai can lay, mac dinh 20 va gioi han toi da 50.
- `p_before_created_at`: moc thoi gian cua cursor, co the null.
- `p_before_post_id`: ID bai viet cua cursor, co the null.

Hai gia tri cursor phai cung null hoac cung co gia tri.

### Dau ra moi dong

- Thong tin bai: ID, noi dung, shared item, thoi gian tao.
- Thong tin tac gia: ID, ten, username/handle va avatar.
- `image_urls`: danh sach URL media theo `position`.
- `like_count`, `comment_count`.
- `is_liked`, `is_bookmarked`, `is_following`, `is_reported`.
- `created_at` va `id_post` cua tung bai duoc dung de Flutter tao cursor tu
  dong cuoi cung cua trang.

RPC khong tra noi dung binh luan va khong tra danh sach nguoi da like.

### Loc du lieu

- Chi tra bai co `status` null hoac `active`.
- Khong tra bai cua tai khoan ma nguoi dung hien tai da block.
- Feed `following` chi tra bai cua tai khoan dang duoc follow.
- Sap xep `created_at desc, id_post desc` de cursor khong mat hoac lap bai khi
  nhieu bai co cung thoi gian.

## Contract `forum_comments_page`

### Dau vao

- `p_post_id`: bai viet can tai binh luan.
- `p_limit`: mac dinh 20, gioi han toi da 50.
- Cursor gom `p_before_created_at` va `p_before_comment_id`.

### Dau ra moi dong

- ID binh luan, noi dung, thoi gian tao.
- Thong tin tac gia can de hien thi.
- `like_count` va `is_liked`.

Binh luan duoc sap xep `created_at desc, id_comment desc`. RPC chi tra binh
luan co `status` null hoac `active`.

## Flutter data flow

### Feed

`ForumRepository.loadSnapshot` su dung `forum_feed_page` cho trang duoc yeu
cau. Snapshot van cung cap `posts`, `forYouFeedIds`, `followingFeedIds` va
profile de giam pham vi thay doi cua `ForumStore`, nhung
`commentsByPostId` rong khi tai feed.

Cursor trong repository/store la mot value object gom `createdAt` va
`postId`, duoc tao tu dong cuoi cung cua trang vua nhan.

### Thread

Khi `ThreadPage` mo:

1. Hien bai viet da co trong store.
2. Goi `ForumStore.ensureCommentsLoaded(postId)`.
3. Hien loading cho lan tai dau.
4. Khi gan cuoi danh sach, goi `loadMoreComments(postId)`.
5. Reply moi duoc chen optimistic vao dau danh sach va tang bo dem bai viet.

Moi bai viet co trang thai binh luan rieng: loading, loading-more, error,
cursor va has-more. Tai lai feed khong xoa binh luan da tai cua bai dang mo.

## Bao mat

- Hai RPC dung `auth.uid()` de xac dinh trang thai like/bookmark/follow/report.
- RPC khong nhan `user_id` tu client.
- RPC dung `security invoker` de tiep tuc ton trong mo hinh quyen cua nguoi
  dung dang nhap va cac bang lien quan.
- Dau vao limit va cursor duoc validate trong function.

## Chi muc

Giu cac chi muc feed hien co va bo sung neu chua co:

- `forum_post(created_at desc, id_post desc)` cho bai active.
- `forum_comment(id_post, created_at desc, id_comment desc)` cho binh luan
  active.
- Cac chi muc theo khoa ngoai cua like, bookmark, media va follow.

## Loi va fallback

- RPC loi thi repository nem loi co ngu canh `Load forum feed failed` hoac
  `Load forum comments failed`.
- Feed cu van hien neu load-more that bai; cursor khong duoc cap nhat.
- Thread cho phep retry rieng ma khong refresh toan bo Forum.
- Khong fallback sang luong nhieu truy van cu, vi fallback nay se che viec
  migration chua duoc deploy va dua diem nghen tro lai production.

## Kiem thu

- SQL: feed loc block/follow dung, dem dung, cursor khong trung va khong mat
  bai, trang thai theo user dung.
- Dart parser: chuyen mot dong RPC thanh `ForumPost` va profile dung.
- Store: load trang dau, append trang sau, comment lan dau, comment trang sau,
  retry va optimistic reply.
- Widget: ThreadPage hien loading, empty, error va load-more ma khong lam mat
  bai viet.

## Tieu chi hoan thanh

- Moi trang feed khong truy van noi dung `forum_comment`.
- Flutter khong tai toan bo like/comment rows de dem.
- Mo ThreadPage moi bat dau tai binh luan.
- Moi request feed/comment bi gioi han toi da 50 dong.
- Tat ca test Forum hien co va test moi deu qua.
