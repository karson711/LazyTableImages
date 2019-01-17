# LazyTableImages
工程讲解
接下来我们就用上面提到的苹果官方示例工程来简单解释一下这个方法的实现过程。打开上面刚下载的LazyTableImages工程，直接进到RootViewController这个类去看就可以了。
RootViewController就是这个示例程序的主控制器，在RootViewController.h头文件中定义了一个叫entries数组
@property (nonatomic, strong) NSArray *entries;

这个entries数组就放着tableview每一行row的模型数据，它是在AppDelegate的程序启动时的方法里就发起的请求，请求回来之后就将数据转模型然后传给这个Controller。
每一行的模型数据是AppRecord类示例，AppRecord类属性如下：
@interface AppRecord : NSObject
@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) UIImage *appIcon;
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *imageURLString;
@property (nonatomic, strong) NSString *appURLString;
@end

刚请求回来的时候只有这行数据图片的url地址叫做imageURLString，当这个图片被请求回来了就将图片对象设置给appIcon属性里，下次再显示这个行时候看到有图片对象就不用请求了。
好的，现在就将目标放到最重要的几个tableView的方法上去，先看到最主要cellForRowAtIndexPath方法，这个方法大家都知道在tableView滚动时候系统会疯狂的调用，让你返回要显示的cell对象给他。请看下面方法和注解，只要重点看那个if else的else里面的代码和注释就可以了，这个if else只是用来判断模型数据是否请求回来了，没有则显示一个正在loading的cell
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


好的，看完了这个方法我们就去看看在上面这个方法里调用的那个开始下载图片的方法是怎么实现的，请看下面方法和注解：
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

如果你觉得这样子就完工了那就错了！！！
因为根据现在这两个方法的实现还只能让tableView在滚动的时候不发起图片加载请求，还不能让tableView停止时候去加载当前显示行的图片，现在我们要想想在哪里可以知道tableView停止了呢？
肯定是UIScrollViewDelegate方法啦！UITableView是继承UIScrollView的嘛。请看下面两个代理方法实现和注释：
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

可以看到这个两个代理方法很简单，我们就是为了定位到tableView停止滚动的那一刻，然后就简单调用了加载当前显示行图片的方法。
接下来再看最后一个方法和注释，就是加载当前显示行图片：
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


至此这个示例工程最主要的几个方法就讲解完了，大家应该对这个官方建议的优化方法理解了吧。当然tableView还有很多其他值得优化的地方和方法，不过这个其实也要具体情况具体分析，不用为了优化而优化。
这个内容来加载的方法也不一定要局限于UITableView或图片，我觉得很多用了UIScrollView复杂界面都可以借鉴使用这个方法
