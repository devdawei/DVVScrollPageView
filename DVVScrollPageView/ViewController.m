//
//  ViewController.m
//  DVVScrollPageView
//
//  Created by David on 2022/2/25.
//

#import "ViewController.h"
#import "DVVSegmentedView.h"
#import "DVVScrollPageView.h"
#import "TestViewController.h"

@interface ViewController () <DVVSegmentedViewDelegate, DVVScrollPageViewDelegate>

@property (nonatomic, strong) DVVSegmentedView *segmentedView;
@property (nonatomic, strong) NSMutableArray<DVVSegmentedModel *> *segmentedModelArray;
@property (nonatomic, strong) DVVScrollPageView *scrollPageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    CGSize size = UIScreen.mainScreen.bounds.size;
    CGFloat naviHeight = 88;
    CGFloat segmentedViewHeight = 44;
    self.segmentedView.frame = CGRectMake(0, naviHeight, size.width, segmentedViewHeight);
    self.scrollPageView.frame = CGRectMake(0, naviHeight + segmentedViewHeight, size.width, size.height - naviHeight - segmentedViewHeight);
    [self.view addSubview:self.segmentedView];
    [self.view addSubview:self.scrollPageView];
    
    NSInteger count = 10;
    _segmentedModelArray = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        NSString *title = [NSString stringWithFormat:@"第%@个", @(i + 1)];
        [self.segmentedModelArray addObject:[self segmentedModelWithTitle:title]];
    }
    [self.segmentedView refreshWithDataModelArray:self.segmentedModelArray];
    [self.scrollPageView refreshWithPageCount:self.segmentedModelArray.count];
}

#pragma mark - DVVSegmentedViewDelegate
#pragma mark 通过点击标题切换页面
- (void)segmentedView:(DVVSegmentedView *)segmentedView didSelectAtIndex:(NSInteger)index {
    [self.scrollPageView selectIndex:index animated:YES];
}

#pragma mark - DVVScrollPageViewDelegate
#pragma mark 返回需要显示的控制器
- (UIViewController *)scrollPageView:(DVVScrollPageView *)scrollPageView viewControllerAtIndex:(NSInteger)index {
    TestViewController *vc = [[TestViewController alloc] init];
    return vc;
}

#pragma mark 页面滚动时调用
- (void)scrollPageView:(DVVScrollPageView *)scrollPageView scrollProgress:(CGFloat)scrollProgress fromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {
    [self.segmentedView refreshItemStatusWithScrollProgress:scrollProgress fromIndex:fromIndex toIndex:toIndex];
}

#pragma mark 切换页面后调用
- (void)scrollPageView:(DVVScrollPageView *)scrollPageView didChangeCurrentSelectedIndex:(NSInteger)index {
    [self.segmentedView selectIndex:index animated:YES];
}

#pragma mark 结束滚动时调用
- (void)scrollPageViewDidEndScrolling:(DVVScrollPageView *)scrollPageView {
    [self.segmentedView refreshItemStatusCompletion];
}

#pragma mark -

- (DVVSegmentedModel *)segmentedModelWithTitle:(NSString *)title {
    DVVSegmentedModel *model = [[DVVSegmentedModel alloc] init];
    
    model.title = title;
    
    model.normalFont = [UIFont systemFontOfSize:15];
    model.selectedFont = [UIFont fontWithName:@"PingFangSC-Medium" size:18];
    
    model.normalTextColor = [UIColor colorWithRed:250/255.0 green:250/255.0 blue:250/255.0 alpha:1];
    model.selectedTextColor = [UIColor whiteColor];
    
    model.normalBackgroundColor = [UIColor clearColor];
    model.selectedBackgroundColor = [UIColor clearColor];
    
    model.followerBarColor = [UIColor orangeColor];
    model.fixedFollowerBarWidth = 30;
    
    return model;
}

#pragma mark -

- (DVVSegmentedView *)segmentedView {
    if (!_segmentedView) {
        _segmentedView = [[DVVSegmentedView alloc] init];
        _segmentedView.backgroundColor = [UIColor colorWithRed:0/255.0 green:100/255.0 blue:255/255.0 alpha:1];
        _segmentedView.delegate = self;
        _segmentedView.contentNeedToCenter = YES;
    }
    return _segmentedView;
}

- (DVVScrollPageView *)scrollPageView {
    if (!_scrollPageView) {
        _scrollPageView = [[DVVScrollPageView alloc] init];
        _scrollPageView.backgroundColor = [UIColor whiteColor];
        _scrollPageView.delegate = self;
        _scrollPageView.rootViewController = self;
        _scrollPageView.bounces = NO;
    }
    return _scrollPageView;
}

@end
