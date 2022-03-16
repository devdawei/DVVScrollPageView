//
//  DVVScrollPageView.m
//  DVVScrollPageView
//
//  Created by David on 2022/2/25.
//

#import "DVVScrollPageView.h"
#import <objc/runtime.h>

@interface DVVScrollPageView () <UIScrollViewDelegate>

@property (nonatomic, readwrite, assign) NSInteger currentSelectedIndex;
@property (nonatomic, assign) NSInteger lastSelectedIndex;

@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, assign) CGFloat lastOffsetX;

@property (nonatomic, assign) NSInteger pageCount;

@property (nonatomic, assign) BOOL refreshAfterConfigUI;

@property (nonatomic, strong) NSMutableDictionary<NSString *, UIViewController *> *viewControllerInfoDict;

/// 正在展示中的下标
@property (nonatomic, strong) NSMutableArray<NSString *> *showingIndexArray;

@property (nonatomic, assign) BOOL isDrag;
/// 在滑动的过程中，正在消失的下标
@property (nonatomic, assign) NSInteger fromIndex;
/// 在滑动的过程中，将要显示的下标
@property (nonatomic, assign) NSInteger toIndex;

@property (nonatomic, assign) BOOL animatedSetContentOffset;
@property (nonatomic, assign) NSInteger animatedToIndex;
/**
 这个是防止通过 - (void)selectIndex:(NSInteger)index animated:(BOOL)animated; 方法滚动，并且 animated 为 YES，
 当还没有滚动完成时，用户通过手动滚动 ScrollView 返回了，则
 */
@property (nonatomic, assign) NSInteger animatedToIndexEndNeedHandleScrollViewUserInteractionEnabled;

@property (nonatomic, assign) BOOL isFirstRefresh;

@end

@implementation DVVScrollPageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _lastSelectedIndex = -1;
        
        _fromIndex = -1;
        _toIndex = -1;
        
        _scrollEnabled = YES;
        
        _bounces = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarningNotification:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
        [self addSubview:self.contentScrollView];
    }
    return self;
}

- (void)didReceiveMemoryWarningNotification:(NSNotification *)notification {
    __block NSMutableArray<NSString *> *exceptionIndexArray = [NSMutableArray array];
    void (^addIdxIfNeed)(NSInteger idx) = ^(NSInteger idx) {
        NSString *idxStr = [NSString stringWithFormat:@"%@", @(idx)];
        if (![exceptionIndexArray containsObject:idxStr]) {
            [exceptionIndexArray addObject:idxStr];
        }
    };
    if (_isDrag && _fromIndex >= 0 && _fromIndex < self.pageCount) {
        addIdxIfNeed(_fromIndex);
    }
    if (_isDrag && _toIndex >= 0 && _toIndex < self.pageCount) {
        addIdxIfNeed(_toIndex);
    }
    if (_animatedSetContentOffset && _animatedToIndex >= 0 && _animatedToIndex < self.pageCount) {
        addIdxIfNeed(_animatedToIndex);
    }
    if (!_isDrag && !_animatedSetContentOffset &&
        self.currentSelectedIndex >=0 && self.currentSelectedIndex < self.pageCount) {
        addIdxIfNeed(self.currentSelectedIndex);
    }
    
    // 移除未显示的视图
    [self removeShowingViewWithExceptionIndexArray:exceptionIndexArray];
    // 移除未显示的控制器
    NSMutableArray *needRemoveIndexArray = [NSMutableArray array];
    for (NSString *idxStr in self.viewControllerInfoDict.allKeys) {
        if ([exceptionIndexArray containsObject:idxStr]) {
            continue;
        }
        [needRemoveIndexArray addObject:idxStr];
    }
    for (NSString *idxStr in needRemoveIndexArray) {
        [self.viewControllerInfoDict removeObjectForKey:idxStr];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(scrollPageView:removedCacheViewControllersWhenReceiveMemoryWarningWithIndexArray:exceptionIndexArray:)]) {
        [self.delegate scrollPageView:self removedCacheViewControllersWhenReceiveMemoryWarningWithIndexArray:needRemoveIndexArray exceptionIndexArray:exceptionIndexArray];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self configUI];
}

- (void)configUI {
    CGSize size = self.bounds.size;
    CGFloat contentScrollViewW = size.width;
    CGSize contentScrollViewSize = self.contentScrollView.bounds.size;
    if ((self.pageCount > 0 && contentScrollViewSize.width == 0) ||
        (self.pageCount > 0 && contentScrollViewSize.width != 0 &&
         contentScrollViewSize.width != contentScrollViewW)) {
        self.contentScrollView.contentSize = CGSizeMake(contentScrollViewW*self.pageCount, 0);
    }
    self.contentScrollView.frame = CGRectMake(0, 0, contentScrollViewW, size.height);
    if (self.refreshAfterConfigUI) {
        self.refreshAfterConfigUI = NO;
        [self firstRefresh];
    }
}

- (void)firstRefresh {
    [self showAtIndex:self.currentSelectedIndex];
    [self selectIndex:self.currentSelectedIndex animated:NO];
    [self viewControllerAtIndex:self.currentSelectedIndex].dvv_scrollPageViewScrolling = NO;
    [self viewControllerAtIndex:self.currentSelectedIndex].dvv_isSelectedInScrollPageView = YES;
}

- (UIViewController *)viewControllerAtIndex:(NSInteger)index {
    NSString *idxStr = [NSString stringWithFormat:@"%@", @(index)];
    if ([self.viewControllerInfoDict.allKeys containsObject:idxStr]) {
        return self.viewControllerInfoDict[idxStr];
    } else {
        return nil;
    }
}

- (void)refreshWithPageCount:(NSInteger)pageCount {
    [self refreshWithPageCount:pageCount selectedIndex:0];
}

- (void)refreshWithPageCount:(NSInteger)pageCount selectedIndex:(NSInteger)selectedIndex {
    // 移除所有的视图
    [self removeShowingViewWithExceptionIndexArray:nil];
    // 移除所有缓存控制器
    [self.viewControllerInfoDict removeAllObjects];
    
    self.pageCount = pageCount;
    self.currentSelectedIndex = selectedIndex;
    self.lastSelectedIndex = self.currentSelectedIndex;
    
    CGFloat contentScrollViewW = self.contentScrollView.bounds.size.width;
    if (contentScrollViewW > 0) {
        self.refreshAfterConfigUI = NO;
        self.contentScrollView.contentSize = CGSizeMake(contentScrollViewW*self.pageCount, 0);
        [self firstRefresh];
    } else {
        self.refreshAfterConfigUI = YES;
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated {
    CGPoint contentOffset = CGPointMake(self.contentScrollView.bounds.size.width*index, 0);
    if (animated) {
        _animatedSetContentOffset = YES;
        _animatedToIndex = index;
        self.contentScrollView.userInteractionEnabled = NO;
        self.animatedToIndexEndNeedHandleScrollViewUserInteractionEnabled = YES;
    }
    [self.contentScrollView setContentOffset:contentOffset animated:animated];
}

- (void)showAtIndexIfNeed:(NSInteger)index {
    if (index < 0 || index >= self.pageCount) {
        return;
    }
    for (NSString *idxStr in self.showingIndexArray) {
        if ([idxStr integerValue] == index) {
            return;
        }
    }
    [self showAtIndex:index];
}

- (void)showAtIndex:(NSInteger)index {
    NSString *idxStr = [NSString stringWithFormat:@"%@", @(index)];
    UIViewController *vc = self.viewControllerInfoDict[idxStr];
    BOOL hasCache = NO;
    if (vc) {
        hasCache = YES;
    }
    if (!hasCache) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(scrollPageView:viewControllerAtIndex:)]) {
            vc = [self.delegate scrollPageView:self viewControllerAtIndex:index];
            if (!vc) {
                return;
            }
        }
    }
    
    [self.rootViewController addChildViewController:vc];
    CGRect frame = self.contentScrollView.bounds;
    frame.origin.x = frame.size.width*index;
    // NSLog(@"%@", NSStringFromCGRect(frame));
    vc.view.frame = frame;
    [self.contentScrollView addSubview:vc.view];
    [vc didMoveToParentViewController:self.rootViewController];
    
    if (!_viewControllerInfoDict) {
        _viewControllerInfoDict = [NSMutableDictionary dictionary];
    }
    if (!hasCache) {
        [self.viewControllerInfoDict setObject:vc forKey:idxStr];
    }
    
    [self addShowingIndexIfNeed:index];
}

- (void)addShowingIndexIfNeed:(NSInteger)index {
    NSString *idxStr = [NSString stringWithFormat:@"%@", @(index)];
    if ([self.showingIndexArray containsObject:idxStr]) {
        return;
    }
    if (!_showingIndexArray) {
        _showingIndexArray = [NSMutableArray array];
    }
    [_showingIndexArray addObject:idxStr];
    for (NSString *idxStr in _showingIndexArray) {
        UIViewController *vc = [self viewControllerAtIndex:[idxStr integerValue]];
        if (!vc.dvv_scrollPageViewScrolling) {
            vc.dvv_scrollPageViewScrolling = YES;
        }
        if (vc.dvv_isSelectedInScrollPageView) {
            vc.dvv_isSelectedInScrollPageView = NO;
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.contentScrollView.bounds.size.width <= 0) {
        return;
    }
    
    BOOL scrollToNext = NO;
    CGFloat currentOffsetX = scrollView.contentOffset.x;
    if (currentOffsetX > _lastOffsetX) {
        // NSLog(@"显示下一个");
        scrollToNext = YES;
    } else {
        // NSLog(@"显示上一个");
        scrollToNext = NO;
    }
    
    CGFloat contentScrollViewW = self.contentScrollView.bounds.size.width;
    NSInteger willShowIndex = 0; // 将要显示的下标
    if (scrollToNext) {
        willShowIndex = ceilf(currentOffsetX/contentScrollViewW);
    } else {
        willShowIndex = floorf(currentOffsetX/contentScrollViewW);
    }
//    NSLog(@"willShowIndex:%@", @(willShowIndex));
    
    // 检查是否需要添加视图
    if (_animatedSetContentOffset) {
        if (willShowIndex == _animatedToIndex) {
            _animatedSetContentOffset = NO;
            [self showAtIndexIfNeed:willShowIndex];
        }
    } else {
        [self showAtIndexIfNeed:willShowIndex];
    }
    
    NSInteger flagIndex = ceilf(currentOffsetX/contentScrollViewW);;
    CGFloat progress = 0;
    if (currentOffsetX == flagIndex*contentScrollViewW) {
        progress = 1;
    } else {
        progress = (currentOffsetX - floor(currentOffsetX/contentScrollViewW)*contentScrollViewW)/contentScrollViewW;
    }
    _fromIndex = 0;
    _toIndex = 0;
    if (scrollToNext) {
        _fromIndex = flagIndex - 1;
        _toIndex = flagIndex;
    } else {
        if (currentOffsetX == flagIndex*contentScrollViewW) {
            _fromIndex = flagIndex + 1;
            _toIndex = flagIndex;
        } else {
            _fromIndex = flagIndex;
            _toIndex = flagIndex - 1;
            progress = 1 - progress;
        }
    }
//    NSLog(@"fromIndex:%@, toIndex:%@, progress:%@", @(_fromIndex), @(_toIndex), @(progress));
    
    if (_isDrag) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(scrollPageView:scrollProgress:fromIndex:toIndex:)]) {
            [self.delegate scrollPageView:self scrollProgress:progress fromIndex:_fromIndex toIndex:_toIndex];
        }
    }
    
    _lastOffsetX = currentOffsetX;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // NSLog(@"将要拖动 %@", @(scrollView.contentOffset.x));
    _isDrag = YES;
}

// called when setContentOffset/scrollRectVisible:animated: finishes. not called if not animating
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    // NSLog(@"减速完成（setContentOffset/scrollRectVisible:animated）");
    [self changeIndex];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    // NSLog(@"减速完成（手动拖动）");
    _isDrag = NO;
    [self changeIndex];
}

#pragma mark -

- (void)changeIndex {
    if (self.animatedToIndexEndNeedHandleScrollViewUserInteractionEnabled) {
        self.contentScrollView.userInteractionEnabled = YES;
    }
    
    CGFloat idx = self.contentScrollView.contentOffset.x/self.contentScrollView.bounds.size.width;
    if (idx != floorf(idx)) {
        return;
    }
    
    self.currentSelectedIndex = idx;
    NSLog(@"改变 currentSelectedIndex %@\n", @(self.currentSelectedIndex));
    
    // 选中当前显示的
    UIViewController *vc = [self viewControllerAtIndex:self.currentSelectedIndex];
    vc.dvv_scrollPageViewScrolling = NO;
    vc.dvv_isSelectedInScrollPageView = YES;
    // 移除其他的
    [self removeShowingViewWithExceptionIndexArray:@[[NSString stringWithFormat:@"%@", @(self.currentSelectedIndex)]]];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(scrollPageViewDidEndScrolling:)]) {
        [self.delegate scrollPageViewDidEndScrolling:self];
    }
    if (self.currentSelectedIndex != self.lastSelectedIndex) {
        self.lastSelectedIndex = self.currentSelectedIndex;
        if (self.delegate && [self.delegate respondsToSelector:@selector(scrollPageView:didChangeCurrentSelectedIndex:)]) {
            [self.delegate scrollPageView:self didChangeCurrentSelectedIndex:self.currentSelectedIndex];
        }
    }
}

- (void)removeShowingViewWithExceptionIndexArray:(NSArray<NSString *> *)exceptionIndexArray {
    NSMutableArray *didRemoveIndexArray = [NSMutableArray array];
    for (NSString *idxStr in self.showingIndexArray) {
        NSInteger idx = [idxStr integerValue];
        if ([exceptionIndexArray containsObject:idxStr]) {
            continue;
        }
        UIViewController *vc = [self viewControllerAtIndex:idx];
        if (vc) {
            vc.dvv_scrollPageViewScrolling = NO;
            vc.dvv_isSelectedInScrollPageView = NO;
            
            [vc willMoveToParentViewController:nil];
            [vc.view removeFromSuperview];
            [vc removeFromParentViewController];
        }
        [didRemoveIndexArray addObject:idxStr];
    }
    NSLog(@"\n%@\n", self.rootViewController.childViewControllers);
    for (NSString *idxStr in didRemoveIndexArray) {
        [self.showingIndexArray removeObject:idxStr];
    }
}

#pragma mark - Setter

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    _scrollEnabled = scrollEnabled;
    self.contentScrollView.scrollEnabled = scrollEnabled;
}

- (void)setBounces:(BOOL)bounces {
    _bounces = bounces;
    self.contentScrollView.bounces = bounces;
}

#pragma mark - Getter

- (UIScrollView *)contentScrollView {
    if (!_contentScrollView) {
        _contentScrollView = [[UIScrollView alloc] init];
        _contentScrollView.pagingEnabled = YES;
        _contentScrollView.delegate = self;
        _contentScrollView.showsHorizontalScrollIndicator = NO;
        if (@available(iOS 11.0, *)) {
            _contentScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        if (@available(iOS 13.0, *)) {
            _contentScrollView.automaticallyAdjustsScrollIndicatorInsets = NO;
        }
    }
    return _contentScrollView;
}

@end


@implementation UIViewController (DVVScrollPageView)

static char DVVScrollPageViewScrolling;

- (void)setDvv_scrollPageViewScrolling:(BOOL)dvv_scrollPageViewScrolling {
    NSLog(@"%@ setDvv_scrollPageViewScrolling: %@", NSStringFromClass(self.class), @(dvv_scrollPageViewScrolling));
    objc_setAssociatedObject(self, &DVVScrollPageViewScrolling, @(dvv_scrollPageViewScrolling), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)dvv_scrollPageViewScrolling {
    id obj = objc_getAssociatedObject(self, &DVVScrollPageViewScrolling);
    if (obj) {
        return [obj boolValue];
    } else {
        // default value.
        return NO;
    }
}

static char DVVIsSelectedInScrollPageView;

- (void)setDvv_isSelectedInScrollPageView:(BOOL)dvv_isSelectedInScrollPageView {
    NSLog(@"%@ setDvv_isSelectedInScrollPageView: %@", NSStringFromClass(self.class), @(dvv_isSelectedInScrollPageView));
    objc_setAssociatedObject(self, &DVVIsSelectedInScrollPageView, @(dvv_isSelectedInScrollPageView), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)dvv_isSelectedInScrollPageView {
    id obj = objc_getAssociatedObject(self, &DVVIsSelectedInScrollPageView);
    if (obj) {
        return [obj boolValue];
    } else {
        // default value.
        return NO;
    }
}

@end
