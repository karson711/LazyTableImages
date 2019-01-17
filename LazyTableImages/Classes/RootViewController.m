/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Controller for the main table view of the LazyTable sample.
  This table view controller works off the AppDelege's data model.
  produce a three-stage lazy load:
  1. No data (i.e. an empty table)
  2. Text-only data from the model's RSS feed
  3. Images loaded over the network asynchronously
  
  This process allows for asynchronous loading of the table to keep the UI responsive.
  Stage 3 is managed by the AppRecord corresponding to each row/cell.
  
  Images are scaled to the desired height.
  If rapid scrolling is in progress, downloads do not begin until scrolling has ended.
 */

#import "RootViewController.h"
#import "AppRecord.h"
#import "IconDownloader.h"

#define kCustomRowCount 7

static NSString *CellIdentifier = @"LazyTableCell";
static NSString *PlaceholderCellIdentifier = @"PlaceholderCell";


#pragma mark -

@interface RootViewController () <UIScrollViewDelegate>

// the set of IconDownloader objects for each app
@property (nonatomic, strong) NSMutableDictionary *imageDownloadsInProgress;

@end


#pragma mark -

@implementation RootViewController

// -------------------------------------------------------------------------------
//	viewDidLoad
// -------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _imageDownloadsInProgress = [NSMutableDictionary dictionary];
}

// -------------------------------------------------------------------------------
//	terminateAllDownloads
// -------------------------------------------------------------------------------
- (void)terminateAllDownloads
{
    // terminate all pending download connections
    NSArray *allDownloads = [self.imageDownloadsInProgress allValues];
    [allDownloads makeObjectsPerformSelector:@selector(cancelDownload)];
    
    [self.imageDownloadsInProgress removeAllObjects];
}

// -------------------------------------------------------------------------------
//	dealloc
//  If this view controller is going away, we need to cancel all outstanding downloads.
// -------------------------------------------------------------------------------
- (void)dealloc
{
    // terminate all pending download connections
    [self terminateAllDownloads];
}

// -------------------------------------------------------------------------------
//	didReceiveMemoryWarning
// -------------------------------------------------------------------------------
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // terminate all pending download connections
    [self terminateAllDownloads];
}


#pragma mark - UITableViewDataSource

// ---------------------------------------------------------------------------
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSUInteger count = self.entries.count;
	
	// if there's no data yet, return enough rows to fill the screen
    if (count == 0)
	{
        return kCustomRowCount;
    }
    return count;
}

//这个if else只是用来判断模型数据是否请求回来了，没有则显示一个正在loading的cell
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    //计算当前数据模型的数组entries的数量
    NSUInteger nodeCount = self.entries.count;
    
    if (nodeCount == 0 && indexPath.row == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:PlaceholderCellIdentifier forIndexPath:indexPath];
    } else {
        //重点是这个else后面的！！！！！！！！！！！！！！！
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        if (nodeCount > 0)
        {
            //取出在这个位置cell对象的模型数据
            AppRecord *appRecord = (self.entries)[indexPath.row];
            
            //将数据文字传给cell的Label显示
            cell.textLabel.text = appRecord.appName;
            cell.detailTextLabel.text = appRecord.artist;
 
            //判断当前模型数据是否已经有图片对象了(即判断是否这个数据的图片已经请求过了)
            if (!appRecord.appIcon)
            {
                //判断当前tableView是否在滚动中（这个方法里最重要的一句判断）
                if (self.tableView.dragging == NO &&
                    self.tableView.decelerating == NO)
                {
                    //如果tableView又未再滚动中，即在停止住状态下则调用开始下载图片的方
                    [self startIconDownload:appRecord forIndexPath:indexPath];
                }
                //不管tableView是否在滚动中，是否要去下载图片，都先将本地的默认占位图显示上去
                cell.imageView.image = [UIImage imageNamed:@"Placeholder.png"];
            }
            else
            {
                //如果这个数据的图片已经请求过了，那么直接显示图片即可
                cell.imageView.image = appRecord.appIcon;
            }
            
            
        }
    }
    
    return cell;
}


#pragma mark - Table cell image support

//开始下载图片
- (void)startIconDownload:(AppRecord *)appRecord forIndexPath:(NSIndexPath *)indexPath
{
    //控制器有一个imageDownloadsInProgress的字典属性，用来保存对应indexPath位置的IconDownloader(图片下载器)对象
    //先判断是否已经有当前indexPath的图片下载器对象，如果有则说明这个位置之前已经开始了下载动作，不用重复开始了
    //IconDownloader是这个工程自定义的下载图片的类，你可以去看看它的实现，也可以不用管
    IconDownloader *iconDownloader = (self.imageDownloadsInProgress)[indexPath];
    
    if (iconDownloader == nil)
    {
        //如果没有则创建一个IconDownloader
        iconDownloader = [[IconDownloader alloc] init];
        
        //将当前位置的数据模型传给IconDownloader
        //IconDownloader内部一会就会根据这个模型对象的图片url地址去下载
        iconDownloader.appRecord = appRecord;
        
        //设置IconDownloader下载完成后的回调block
        [iconDownloader setCompletionHandler:^{
            
            //先取到对应indexPath位置的cell
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            
            //让cell显示模型数据新下载到的图片对象
            //appRecord的appIcon图片对象的赋值在IconDownloader内部就自动完成了
            cell.imageView.image = appRecord.appIcon;
            
            //将这个完成下载的IconDownloader从控制器的imageDownloadsInProgress字典里移除掉
            [self.imageDownloadsInProgress removeObjectForKey:indexPath];
            
        }];
        //将这个准备开始下载图片的IconDownloader加入到控制器的imageDownloadsInProgress字典里
        (self.imageDownloadsInProgress)[indexPath] = iconDownloader;
        //开始下载图片
        [iconDownloader startDownload];
        
    }
}

// 加载当前显示行图片
- (void)loadImagesForOnscreenRows
{
    //判断模型数据是否为空，为空说明模型数据都还没请求回来，也就不毕继续加载图片动作
    if (self.entries.count > 0)
    {
        //获取当前屏幕上可以见所有行对应的indexPath位置组成的数组
        NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
        //遍历所有位置
        for (NSIndexPath *indexPath in visiblePaths)
        {
            //取到对应位置的模型数据
            AppRecord *appRecord = (self.entries)[indexPath.row];
            
            //判断这个模型数据是否已经有图片对象了，如果有说明已经下载过了
            if (!appRecord.appIcon)
            {
                //如果还未下载过则去开始下载对应行的图片
                [self startIconDownload:appRecord forIndexPath:indexPath];
            }
        }
    }
}

#pragma mark - UIScrollViewDelegate
//用户停止拖动了scrollView(手指结束拖拽动作离开屏幕了)，准备开始减速滚动时会调用
//由于惯性，用户手指离开屏幕后还会继续滚动一会，这个decelerate(减速)就是指这个后续的滚动状态
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    //判断是否已经停止减速了
    if (!decelerate)
    {
        //调用加载当前显示行图片方法
        [self loadImagesForOnscreenRows];
    }
}

//scrollView停止减速后会调用
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    //调用加载当前显示行图片方法
    [self loadImagesForOnscreenRows];
}


@end
