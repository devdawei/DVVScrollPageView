//
//  DVVScrollPageView.h
//  DVVScrollPageView
//
//  Created by David on 2022/2/25.
//

#import <UIKit/UIKit.h>

@protocol DVVScrollPageViewDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface DVVScrollPageView : UIView

/// 当前选中的下标  default: 0
@property (nonatomic, readonly, assign) NSInteger currentSelectedIndex;

/// 是否可以滚动  default: YES
@property (nonatomic, assign) BOOL scrollEnabled;

/// 是否支持弹簧效果  default: YES
@property (nonatomic, assign) BOOL bounces;

@property (nonatomic, weak) UIViewController *rootViewController;

@property (nonatomic, weak) id<DVVScrollPageViewDelegate> delegate;

- (void)refreshWithPageCount:(NSInteger)pageCount;

- (void)refreshWithPageCount:(NSInteger)pageCount selectedIndex:(NSInteger)selectedIndex;

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated;

@end


@protocol DVVScrollPageViewDelegate <NSObject>

@required

/// 获取一个控制器时调用
- (UIViewController *)scrollPageView:(DVVScrollPageView *)scrollPageView viewControllerAtIndex:(NSInteger)index;

@optional

/// 已经改变了当前选中的控制器后调用
- (void)scrollPageView:(DVVScrollPageView *)scrollPageView didChangeCurrentSelectedIndex:(NSInteger)index;

/// 手动滚动时调用
- (void)scrollPageView:(DVVScrollPageView *)scrollPageView scrollProgress:(CGFloat)scrollProgress fromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex;

/// 结束滚动时调用
- (void)scrollPageViewDidEndScrolling:(DVVScrollPageView *)scrollPageView;

/**
 接收到内存警告时调用

 @param indexArray 已经从缓存中释放的控制器下标
 @param exceptionIndexArray 忽略的控制器下标
 */
- (void)scrollPageView:(DVVScrollPageView *)scrollPageView
removedCacheViewControllersWhenReceiveMemoryWarningWithIndexArray:(NSArray<NSString *> *)indexArray
           exceptionIndexArray:(NSArray<NSString *> *)exceptionIndexArray;

@end


@interface UIViewController (DVVScrollPageView)

/// DVVScrollPageView 是否正在滚动
@property (nonatomic, assign) BOOL dvv_scrollPageViewScrolling;

/// 此控制器在 DVVScrollPageView 中是否为选中的控制器
@property (nonatomic, assign) BOOL dvv_isSelectedInScrollPageView;

@end

NS_ASSUME_NONNULL_END
