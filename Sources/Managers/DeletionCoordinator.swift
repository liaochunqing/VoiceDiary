import Foundation
import SwiftUI

/// 批量删除协调器：设置页「删除全部日记」时先置 `isBulkDeleting = true`，
/// 让列表页在动 context 之前就把所有 `DiaryRow` 从视图层级移除。
///
/// 为什么需要它：`DiaryEntry.photos` 是 `@Attribute(.externalStorage)`，访问时需回
/// context 解 fault。`context.delete + save` 后 backing data 被 detach，此时若
/// `DiaryRow.body` 仍访问 `entry.photos` 就会触发
/// "This backing data was detached from a context without resolving attribute faults" 崩溃。
/// 单条删除靠 `DiaryListView.deletedIDs` 提前移除行来规避；批量删除从设置页触发，
/// 摸不到列表页的 `@State`，故提升到环境对象统一协调。
@Observable
final class DeletionCoordinator {
    /// 正在批量删除：列表页据此跳过 `DiaryRow` 渲染。
    var isBulkDeleting = false
    /// 单条删除（含详情页删除）时，先把 entry id 加入此集合，让列表页立即把对应
    /// `DiaryRow` 从 `ForEach` 移除，再延迟动 context。作用同 `isBulkDeleting`，
    /// 只是粒度到单条。
    var hiddenIDs: Set<UUID> = []
}
