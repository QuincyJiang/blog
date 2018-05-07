title: view 绘制机制
date: 2017/10/12 19:30:50
categories: Android
comments: true
tags: [android]
---
View的绘制和事件处理是两个重要的主题，上一篇《图解 Android事件分发机制》已经把事件的分发机制讲得比较详细了，这一篇是针对View的绘制，View的绘制如果你有所了解，基本分为measure、layout、draw 过程，其中比较难理解就是measure过程，所以本篇文章大幅笔地分析measure过程，相对讲得比较详细，文章也比较长，如果你对View的绘制还不是很懂，对measure过程掌握得不是很深刻，那么耐心点，看完这篇文章，相信你会有所收获的。


# Measure过程
对于测量我们来说几个知识点,了解这几个知识点，之后的实例分析你才看得懂。
## 1、MeasureSpec 的理解
对于View的测量，肯定会和**MeasureSpec**接触，**MeasureSpec**是两个单词组成，翻译过来“测量规格”或者“测量参数”，很多博客包括官方文档对他的说明基本都是“一个MeasureSpec封装了从父容器传递给子容器的布局要求”,这个MeasureSpec 封装的是父容器传递给子容器的布局要求，而不是父容器对子容器的布局要求，“传递” 两个字很重要，更精确的说法应该这个MeasureSpec是由父View的MeasureSpec和子View的LayoutParams通过简单的计算得出一个针对子View的测量要求，这个测量要求就是MeasureSpec。

大家都知道一个MeasureSpec是一个大小跟模式的组合值,MeasureSpec中的值是一个整型（32位）将size和mode打包成一个Int型，其中高两位是mode，后面30位存的是size，是为了减少对象的分配开支。MeasureSpec 类似于下图，只不过这边用的是十进制的数，而MeasureSpec 是二进制存储的。
![image](https://upload-images.jianshu.io/upload_images/966283-c330852c971b02a8.png)
###### 注：-1 代表的是EXACTLY，-2 是AT_MOST
MeasureSpec一共有三种模式


```
UPSPECIFIED : 父容器对于子容器没有任何限制,子容器想要多大就多大
EXACTLY: 父容器已经为子容器设置了尺寸,子容器应当服从这些边界,不论子容器想要多大的空间。
AT_MOST：子容器可以是声明大小内的任意大小
```


很多文章都会把这三个模式说成这样，当然其实包括官方文档也是这样表达的，但是这样并不好理解。特别是如果把这三种模式又和**MATCH_PARENT**和**WRAP_CONTENT** 联系到一起，很多人就懵逼了。如果从代码上来看
```
view.measure(int widthMeasureSpec, int heightMeasureSpec)
```

```

```
 的两个MeasureSpec是父类传递过来的，但并不是完全是父View的要求，而是父View的MeasureSpec和子View自己的LayoutParams共同决定的，而子View的LayoutParams其实就是我们在xml写的时候设置的layout_width和layout_height 转化而来的。我们先来看代码会清晰一些：

父View的measure的过程会先测量子View，等子View测量结果出来后，再来测量自己，上面的measureChildWithMargins就是用来测量某个子View的，我们来分析是怎样测量的，具体看注释：


```java
protected void measureChildWithMargins(View child, int parentWidthMeasureSpec, int widthUsed, int parentHeightMeasureSpec, int heightUsed) { 

// 子View的LayoutParams，你在xml的layout_width和layout_height,
// layout_xxx的值最后都会封装到这个个LayoutParams。
final MarginLayoutParams lp = (MarginLayoutParams) child.getLayoutParams();   

//根据父View的测量规格和父View自己的Padding，
//还有子View的Margin和已经用掉的空间大小（widthUsed），就能算出子View的MeasureSpec,具体计算过程看getChildMeasureSpec方法。
final int childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec,            
mPaddingLeft + mPaddingRight + lp.leftMargin + lp.rightMargin + widthUsed, lp.width);    

final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,           
mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin  + heightUsed, lp.height);  

//通过父View的MeasureSpec和子View的自己LayoutParams的计算，算出子View的MeasureSpec，然后父容器传递给子容器的
// 然后让子View用这个MeasureSpec（一个测量要求，比如不能超过多大）去测量自己，如果子View是ViewGroup 那还会递归往下测量。
child.measure(childWidthMeasureSpec, childHeightMeasureSpec);

}

// spec参数   表示父View的MeasureSpec 
// padding参数    父View的Padding+子View的Margin，父View的大小减去这些边距，才能精确算出
//               子View的MeasureSpec的size
// childDimension参数  表示该子View内部LayoutParams属性的值（lp.width或者lp.height）
//                    可以是wrap_content、match_parent、一个精确指(an exactly size),  
public static int getChildMeasureSpec(int spec, int padding, int childDimension) {  
    int specMode = MeasureSpec.getMode(spec);  //获得父View的mode  
    int specSize = MeasureSpec.getSize(spec);  //获得父View的大小  

   //父View的大小-自己的Padding+子View的Margin，得到值才是子View的大小。
    int size = Math.max(0, specSize - padding);   
  
    int resultSize = 0;    //初始化值，最后通过这个两个值生成子View的MeasureSpec
    int resultMode = 0;    //初始化值，最后通过这个两个值生成子View的MeasureSpec
  
    switch (specMode) {  
    // Parent has imposed an exact size on us  
    //1、父View是EXACTLY的 ！  
    case MeasureSpec.EXACTLY:   
        //1.1、子View的width或height是个精确值 (an exactly size)  
        if (childDimension >= 0) {            
            resultSize = childDimension;         //size为精确值  
            resultMode = MeasureSpec.EXACTLY;    //mode为 EXACTLY 。  
        }   
        //1.2、子View的width或height为 MATCH_PARENT/FILL_PARENT   
        else if (childDimension == LayoutParams.MATCH_PARENT) {  
            // Child wants to be our size. So be it.  
            resultSize = size;                   //size为父视图大小  
            resultMode = MeasureSpec.EXACTLY;    //mode为 EXACTLY 。  
        }   
        //1.3、子View的width或height为 WRAP_CONTENT  
        else if (childDimension == LayoutParams.WRAP_CONTENT) {  
            // Child wants to determine its own size. It can't be  
            // bigger than us.  
            resultSize = size;                   //size为父视图大小  
            resultMode = MeasureSpec.AT_MOST;    //mode为AT_MOST 。  
        }  
        break;  
  
    // Parent has imposed a maximum size on us  
    //2、父View是AT_MOST的 ！      
    case MeasureSpec.AT_MOST:  
        //2.1、子View的width或height是个精确值 (an exactly size)  
        if (childDimension >= 0) {  
            // Child wants a specific size... so be it  
            resultSize = childDimension;        //size为精确值  
            resultMode = MeasureSpec.EXACTLY;   //mode为 EXACTLY 。  
        }  
        //2.2、子View的width或height为 MATCH_PARENT/FILL_PARENT  
        else if (childDimension == LayoutParams.MATCH_PARENT) {  
            // Child wants to be our size, but our size is not fixed.  
            // Constrain child to not be bigger than us.  
            resultSize = size;                  //size为父视图大小  
            resultMode = MeasureSpec.AT_MOST;   //mode为AT_MOST  
        }  
        //2.3、子View的width或height为 WRAP_CONTENT  
        else if (childDimension == LayoutParams.WRAP_CONTENT) {  
            // Child wants to determine its own size. It can't be  
            // bigger than us.  
            resultSize = size;                  //size为父视图大小  
            resultMode = MeasureSpec.AT_MOST;   //mode为AT_MOST  
        }  
        break;  
  
    // Parent asked to see how big we want to be  
    //3、父View是UNSPECIFIED的 ！  
    case MeasureSpec.UNSPECIFIED:  
        //3.1、子View的width或height是个精确值 (an exactly size)  
        if (childDimension >= 0) {  
            // Child wants a specific size... let him have it  
            resultSize = childDimension;        //size为精确值  
            resultMode = MeasureSpec.EXACTLY;   //mode为 EXACTLY  
        }  
        //3.2、子View的width或height为 MATCH_PARENT/FILL_PARENT  
        else if (childDimension == LayoutParams.MATCH_PARENT) {  
            // Child wants to be our size... find out how big it should  
            // be  
            resultSize = 0;                        //size为0！ ,其值未定  
            resultMode = MeasureSpec.UNSPECIFIED;  //mode为 UNSPECIFIED  
        }   
        //3.3、子View的width或height为 WRAP_CONTENT  
        else if (childDimension == LayoutParams.WRAP_CONTENT) {  
            // Child wants to determine its own size.... find out how  
            // big it should be  
            resultSize = 0;                        //size为0! ，其值未定  
            resultMode = MeasureSpec.UNSPECIFIED;  //mode为 UNSPECIFIED  
        }  
        break;  
    }  
    //根据上面逻辑条件获取的mode和size构建MeasureSpec对象。  
    return MeasureSpec.makeMeasureSpec(resultSize, resultMode);  
}
```

上面的代码有点多，希望你仔细看一些注释，代码写得很多，其实计算原理很简单：
 


1. 如果我们在xml 的layout_width或者layout_height 把值都写死，那么上述的测量完全就不需要了，之所以要上面的这步测量，是因为 match_parent 就是充满父容器，wrap_content 就是自己多大就多大， 我们写代码的时候特别爽，我们编码方便的时候，google就要帮我们计算你match_parent的时候是多大，wrap_content的是多大，这个计算过程，就是计算出来的父View的MeasureSpec不断往子View传递，结合子View的LayoutParams 一起再算出子View的MeasureSpec，然后继续传给子View，不断计算每个View的MeasureSpec，子View有了MeasureSpec才能更测量自己和自己的子View。



 
2. 上述代码如果这么来理解就简单了
> 如果父View的MeasureSpec 是EXACTLY，说明父View的大小是确切的，（确切的意思很好理解，如果一个View的MeasureSpec 是EXACTLY，那么它的size 是多大，最后展示到屏幕就一定是那么大）。
* 1.如果子View 的layout_xxxx是MATCH_PARENT，父View的大小是确切，子View的大小又MATCH_PARENT（充满整个父View），那么子View的大小肯定是确切的，而且大小值就是父View的size。所以子View的size=父View的size，mode=EXACTLY

 * 2.如果子View 的layout_xxxx是WRAP_CONTENT，也就是子View的大小是根据自己的content 来决定的，但是子View的毕竟是子View，大小不能超过父View的大小，但是子View的是WRAP_CONTENT，我们还不知道具体子View的大小是多少，要等到child.measure(childWidthMeasureSpec, childHeightMeasureSpec) 调用的时候才去真正测量子View 自己content的大小（比如TextView wrap_content 的时候你要测量TextView content 的大小，也就是字符占用的大小，这个测量就是在child.measure(childWidthMeasureSpec, childHeightMeasureSpec)的时候，才能测出字符的大小，MeasureSpec 的意思就是假设你字符100px，但是MeasureSpec 要求最大的只能50px，这时候就要截掉了）。通过上述描述，子View MeasureSpec mode的应该是AT_MOST，而size 暂定父View的 size，表示的意思就是子View的大小没有不确切的值，子View的大小最大为父View的大小，不能超过父View的大小（这就是AT_MOST 的意思），然后这个MeasureSpec 做为子View measure方法 的参数，做为子View的大小的约束或者说是要求，有了这个MeasureSpec子View再实现自己的测量。

3、如果如果子View 的layout_xxxx是确定的值（200dp），那么就更简单了，不管你父View的mode和size是什么，我都写死了就是200dp，那么控件最后展示就是就是200dp，不管我的父View有多大，也不管我自己的content 有多大，反正我就是这么大，所以这种情况MeasureSpec 的mode = EXACTLY 大小size=你在layout_xxxx 填的那个值。

> 如果父View的MeasureSpec 是AT_MOST，说明父View的大小是不确定，最大的大小是MeasureSpec 的size值，不能超过这个值。

* 1、如果子View 的layout_xxxx是MATCH_PARENT，父View的大小是不确定（只知道最大只能多大），子View的大小MATCH_PARENT（充满整个父View），那么子View你即使充满父容器，你的大小也是不确定的，父View自己都确定不了自己的大小，你MATCH_PARENT你的大小肯定也不能确定的，所以子View的mode=AT_MOST，size=父View的size，也就是你在布局虽然写的是MATCH_PARENT，但是由于你的父容器自己的大小不确定，导致子View的大小也不确定，只知道最大就是父View的大小。

* 2、如果子View 的layout_xxxx是WRAP_CONTENT，父View的大小是不确定（只知道最大只能多大），子View又是WRAP_CONTENT，那么在子View的Content没算出大小之前，子View的大小最大就是父View的大小，所以子View MeasureSpec mode的就是AT_MOST，而size 暂定父View的 size。

* 3、如果如果子View 的layout_xxxx是确定的值（200dp），同上，写多少就是多少，改变不了的。

> 如果父View的MeasureSpec 是UNSPECIFIED(未指定),表示没有任何束缚和约束，不像AT_MOST表示最大只能多大，不也像EXACTLY表示父View确定的大小，子View可以得到任意想要的大小，不受约束
* 1、如果子View 的layout_xxxx是MATCH_PARENT，因为父View的MeasureSpec是UNSPECIFIED，父View自己的大小并没有任何约束和要求，
那么对于子View来说无论是WRAP_CONTENT还是MATCH_PARENT，子View也是没有任何束缚的，想多大就多大，没有不能超过多少的要求，一旦没有任何要求和约束，size的值就没有任何意义了，所以一般都直接设置成0

* 2、同上...

* 3、如果如果子View 的layout_xxxx是确定的值（200dp），同上，写多少就是多少，改变不了的（记住，只有设置的确切的值，那么无论怎么测量，大小都是不变的，都是你写的那个值）

到此为止，你是否对MeasureSpec 和三种模式、还有WRAP_CONTENT和MATCH_PARENT有一定的了解了，如果还有任何问题，欢迎在我简书（用户名：Kelin）评论里留言。

## 2、View的测量过程主要是在onMeasure()方法
打开View的源码，找到measure方法，这个方法代码不少，但是测量工作都是在onMeasure()做的，measure方法是final的所以这个方法也不可重写，如果想自定义View的测量，你应该去重写onMeasure()方法


```java
public final void measure(int widthMeasureSpec, int heightMeasureSpec) {
  ......
  onMeasure(widthMeasureSpec,heightMeasureSpec);
  .....
}
```

## 3、View的onMeasure 的默认实现
打开View.java 的源码来看下onMeasure的实现


```java
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {    
  setMeasuredDimension(
  getDefaultSize(getSuggestedMinimumWidth(), widthMeasureSpec),            
  getDefaultSize(getSuggestedMinimumHeight(), heightMeasureSpec));
}
```

View的onMeasure方法默认实现很简单，就是调用setMeasuredDimension()，setMeasuredDimension()可以简单理解就是给mMeasuredWidth和mMeasuredHeight设值，如果这两个值一旦设置了，那么意味着对于这个View的测量结束了，这个View的宽高已经有测量的结果出来了。如果我们想设定某个View的高宽，完全可以直接通过setMeasuredDimension（100，200）来设置死它的高宽（不建议），但是setMeasuredDimension方法必须在onMeasure方法中调用，不然会抛异常。我们来看下对于View来说它的默认高宽是怎么获取的。



```java
//获取的是android:minHeight属性的值或者View背景图片的大小值
protected int getSuggestedMinimumWidth() { 
   return (mBackground == null) ? mMinWidth : max(mMinWidth, mBackground.getMinimumWidth()); 
} 
//@param size参数一般表示设置了android:minHeight属性或者该View背景图片的大小值  
public static int getDefaultSize(int size, int measureSpec) {    
   int result = size;    
   int specMode = MeasureSpec.getMode(measureSpec);    
   int specSize = MeasureSpec.getSize(measureSpec);    
   switch (specMode) {    
   case MeasureSpec.UNSPECIFIED:        //表示该View的大小父视图未定，设置为默认值 
     result = size;  
     break;    
   case MeasureSpec.AT_MOST:    
   case MeasureSpec.EXACTLY:        
     result = specSize;  
     break;   
 }    
return result;
}
```

getDefaultSize的第一个参数size等于getSuggestedMinimumXXXX返回的的值（建议的最小宽度和高度），而建议的最小宽度和高度都是由View的Background尺寸与通过设置View的minXXX属性共同决定的，这个size可以理解为View的默认长度，而第二个参数measureSpec，是父View传给自己的MeasureSpec,这个measureSpec是通过测量计算出来的，具体的计算测量过程前面在讲解MeasureSpec已经讲得比较清楚了（是有父View的MeasureSpec和子View自己的LayoutParams 共同决定的）只要这个测试的mode不是UNSPECIFIED（未确定的），那么默认的就会用这个测量的数值当做View的高度。

对于View默认是测量很简单，大部分情况就是拿计算出来的MeasureSpec的size 当做最终测量的大小。而对于其他的一些View的派生类，如TextView、Button、ImageView等，它们的onMeasure方法系统了都做了重写，不会这么简单直接拿 MeasureSpec 的size来当大小，而去会先去测量字符或者图片的高度等，然后拿到View本身content这个高度（字符高度等），如果MeasureSpec是AT_MOST，而且View本身content的高度不超出MeasureSpec的size，那么可以直接用View本身content的高度（字符高度等），而不是像View.java 直接用MeasureSpec的size做为View的大小。

## 4、ViewGroup的Measure过程
ViewGroup 类并没有实现onMeasure，我们知道测量过程其实都是在onMeasure方法里面做的，我们来看下FrameLayout 的onMeasure 方法,具体分析看注释哦。

```java
//FrameLayout 的测量
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {  
....
int maxHeight = 0;
int maxWidth = 0;
int childState = 0;
for (int i = 0; i < count; i++) {    
   final View child = getChildAt(i);    
   if (mMeasureAllChildren || child.getVisibility() != GONE) {   
    // 遍历自己的子View，只要不是GONE的都会参与测量，measureChildWithMargins方法在最上面
    // 的源码已经讲过了，如果忘了回头去看看，基本思想就是父View把自己的MeasureSpec 
    // 传给子View结合子View自己的LayoutParams 算出子View 的MeasureSpec，然后继续往下传，
    // 传递叶子节点，叶子节点没有子View，根据传下来的这个MeasureSpec测量自己就好了。
     measureChildWithMargins(child, widthMeasureSpec, 0, heightMeasureSpec, 0);       
     final LayoutParams lp = (LayoutParams) child.getLayoutParams(); 
     maxWidth = Math.max(maxWidth, child.getMeasuredWidth() +  lp.leftMargin + lp.rightMargin);        
     maxHeight = Math.max(maxHeight, child.getMeasuredHeight() + lp.topMargin + lp.bottomMargin);  
     ....
     ....
   }
}
.....
.....
```

//所有的孩子测量之后，经过一系类的计算之后通过setMeasuredDimension设置自己的宽高，
//对于FrameLayout 可能用最大的字View的大小，对于LinearLayout，可能是高度的累加，
//具体测量的原理去看看源码。总的来说，父View是等所有的子View测量结束之后，再来测量自己。

```java
setMeasuredDimension(resolveSizeAndState(maxWidth, widthMeasureSpec, childState),        
resolveSizeAndState(maxHeight, heightMeasureSpec, childState << MEASURED_HEIGHT_STATE_SHIFT));
....
}
```

到目前为止，基本把Measure 主要原理都过了一遍，接下来我们会结合实例来讲解整个match的过程，首先看下面的代码：


```
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout  xmlns:android="http://schemas.android.com/apk/res/android"    
   android:id="@+id/linear"
   android:layout_width="match_parent"    
   android:layout_height="wrap_content"    
   android:layout_marginTop="50dp"    
   android:background="@android:color/holo_blue_dark"    
   android:paddingBottom="70dp"    
   android:orientation="vertical">    
   <TextView        
    android:id="@+id/text"       
    android:layout_width="match_parent"     
    android:layout_height="wrap_content"  
    android:background="@color/material_blue_grey_800"       
    android:text="TextView"        
    android:textColor="@android:color/white"        
    android:textSize="20sp" />    
   <View       
      android:id="@+id/view"       
     android:layout_width="match_parent" 
     android:layout_height="150dp"    
     android:background="@android:color/holo_green_dark" />
</LinearLayout>
```
![image](https://upload-images.jianshu.io/upload_images/966283-4a11f92ac8c5e224.png)
上面的代码对于出来的布局是下面的一张图


对于上面图可能有些不懂，这边做下说明:

> 整个图是一个DecorView,DecorView可以理解成整个页面的根View,DecorView是一个FrameLayout,包含两个子View，一个id=statusBarBackground的View和一个是LineaLayout，id=statusBarBackground的View，我们可以先不管（我也不是特别懂这个View,应该就是statusBar的设置背景的一个控件，方便设置statusBar的背景)，而这个LinearLayout比较重要，它包含一个title和一个content，title很好理解其实就是TitleBar或者ActionBar,content 就更简单了，setContentView()方法你应该用过吧，android.R.id.content 你应该听过吧，没错就是它,content是一个FrameLayout，你写的页面布局通过setContentView加进来就成了content的直接子View。

整个View的布局图如下：

![image](https://upload-images.jianshu.io/upload_images/966283-4096801e91e2eccc.png)
这张图在下面分析measure，会经常用到，主要用于了解递归的时候view 的measure顺序

> 注:
1、 header的是个ViewStub,用来惰性加载ActionBar，为了便于分析整个测量过程，我把Theme设成NoActionBar，避免ActionBar 相关的measure干扰整个过程，这样可以忽略掉ActionBar 的测量，在调试代码更清晰。
2、包含Header(ActionBar）和id/content 的那个父View，我不知道叫什么名字好，我们姑且叫它ViewRoot（看上图）,它是垂直的LinearLayout，放着整个页面除statusBar 的之外所有的东西，叫它ViewRoot 应该还ok，一个代号而已。

既然我们知道整个View的Root是DecorView，那么View的绘制是从哪里开始的呢，我们知道每个Activity 均会创建一个 PhoneWindow对象，是Activity和整个View系统交互的接口，每个Window都对应着一个View和一个ViewRootImpl，Window和View通过ViewRootImpl来建立联系,对于Activity来说，ViewRootImpl是连接WindowManager和DecorView的纽带,绘制的入口是由ViewRootImpl的performTraversals方法来发起Measure，Layout，Draw等流程的。

我们来看下ViewRootImpl的performTraversals 方法：


```java
private void performTraversals() { 
...... 
int childWidthMeasureSpec = getRootMeasureSpec(mWidth, lp.width); 
int childHeightMeasureSpec = getRootMeasureSpec(mHeight, lp.height); 
...... 
mView.measure(childWidthMeasureSpec, childHeightMeasureSpec); 
......
mView.layout(0, 0, mView.getMeasuredWidth(), mView.getMeasuredHeight());
...... 
mView.draw(canvas); 
......
}

private static int getRootMeasureSpec(int windowSize, int rootDimension) { 
   int measureSpec; 
   switch (rootDimension) { 
   case ViewGroup.LayoutParams.MATCH_PARENT: 
   // Window can't resize. Force root view to be windowSize.   
   measureSpec = MeasureSpec.makeMeasureSpec(windowSize,MeasureSpec.EXACTLY);
   break; 
   ...... 
  } 
 return measureSpec; 
}
```

performTraversals 中我们看到的mView其实就是DecorView,View的绘制从DecorView开始， 在mView.measure()的时候调用getRootMeasureSpec获得两个MeasureSpec做为参数，getRootMeasureSpec的两个参数（mWidth, lp.width）mWith和mHeight 是屏幕的宽度和高度， lp是WindowManager.LayoutParams，它的lp.width和lp.height的默认值是MATCH_PARENT,所以通过getRootMeasureSpec 生成的测量规格MeasureSpec 的mode是MATCH_PARENT ，size是屏幕的高宽。
因为DecorView 是一个FrameLayout 那么接下来会进入FrameLayout 的measure方法，measure的两个参数就是刚才getRootMeasureSpec的生成的两个MeasureSpec，DecorView的测量开始了。
首先是DecorView 的 MeasureSpec ，根据上面的分析DecorView 的 MeasureSpec是Windows传过来的，我们画出DecorView 的MeasureSpec 图：

![image](https://upload-images.jianshu.io/upload_images/966283-c330852c971b02a8.png)

> 注：
1、-1 代表的是EXACTLY，-2 是AT_MOST
2、由于屏幕的像素是1440x2560,所以DecorView 的MeasureSpec的size 对应于这两个值

那么接下来在FrameLayout 的onMeasure()方法DecorView开始for循环测量自己的子View,测量完所有的子View再来测量自己，由下图可知，接下来要测量ViewRoot的大小
![image](https://upload-images.jianshu.io/upload_images/966283-4096801e91e2eccc.png)



```java
//FrameLayout 的测量
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {  
....
int maxHeight = 0;
int maxWidth = 0;
int childState = 0;
for (int i = 0; i < count; i++) {    
   final View child = getChildAt(i);    
   if (mMeasureAllChildren || child.getVisibility() != GONE) {   
    // 遍历自己的子View，只要不是GONE的都会参与测量，measureChildWithMargins方法在最上面
    // 的源码已经讲过了，如果忘了回头去看看，基本思想就是父View把自己当MeasureSpec 
    // 传给子View结合子View自己的LayoutParams 算出子View 的MeasureSpec，然后继续往下穿，
    // 传递叶子节点，叶子节点没有子View，只要负责测量自己就好了。
     measureChildWithMargins(child, widthMeasureSpec, 0, heightMeasureSpec, 0);      
     ....
     ....
   }
}
....
}
```

DecorView 测量ViewRoot 的时候把自己的widthMeasureSpec和heightMeasureSpec传进去了，接下来你就要去看measureChildWithMargins的源码了


```java
protected void measureChildWithMargins(View child, int parentWidthMeasureSpec, int widthUsed, int parentHeightMeasureSpec, int heightUsed) { 

final MarginLayoutParams lp = (MarginLayoutParams) child.getLayoutParams();   

final int childWidthMeasureSpec = getChildMeasureSpec(parentWidthMeasureSpec,            
mPaddingLeft + mPaddingRight + lp.leftMargin + lp.rightMargin + widthUsed, lp.width);    

final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,           
mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin  + heightUsed, lp.height);  

child.measure(childWidthMeasureSpec, childHeightMeasureSpec);
}
```

ViewRoot 是系统的View，它的LayoutParams默认都是match_parent,根据我们文章最开始MeasureSpec 的计算规则，ViewRoot 的MeasureSpec mode应该等于EXACTLY（DecorView MeasureSpec 的mode是EXACTLY，ViewRoot的layoutparams 是match_parent），size 也等于DecorView的size，所以ViewRoot的MeasureSpec图如下：
![image](https://upload-images.jianshu.io/upload_images/966283-ed0ffedcca47672a.png)

算出ViewRoot的MeasureSpec 之后，开始调用ViewRoot.measure 方法去测量ViewRoot的大小，然而ViewRoot是一个LinearLayout ，ViewRoot.measure最终会执行的LinearLayout 的onMeasure 方法，LinearLayout 的onMeasure 方法又开始逐个测量它的子View，上面的measureChildWithMargins方法又会被调用，那么根据View的层级图，接下来测量的是header（ViewStub）,由于header的Gone，所以直接跳过不做测量工作，所以接下来轮到ViewRoot的第二个child content（android.R.id.content）,我们要算出这个content 的MeasureSpec，所以又要拿ViewRoot 的MeasureSpec 和 android.R.id.content的LayoutParams 做计算了，计算过程就是调用getChildMeasureSpec的方法，

![image](https://upload-images.jianshu.io/upload_images/966283-527eb25fd49d38ef.png)


```java
protected void measureChildWithMargins(View child, int parentWidthMeasureSpec, int widthUsed, int parentHeightMeasureSpec, int heightUsed) { 
   .....
   final int childHeightMeasureSpec = getChildMeasureSpec(parentHeightMeasureSpec,           
mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin  + heightUsed, lp.height);  
   ....
}

public static int getChildMeasureSpec(int spec, int padding, int childDimension) {  
    int specMode = MeasureSpec.getMode(spec);  //获得父View的mode  
    int specSize = MeasureSpec.getSize(spec);  //获得父View的大小  
  
    int size = Math.max(0, specSize - padding); //父View的大小-自己的Padding+子View的Margin，得到值才是子View可能的最大值。  
     .....
}
```

由上面的代码

```
int size = Math.max(0, specSize - padding);
```

而 
```
padding=mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin + heightUsed
```

算出android.R.id.content 的MeasureSpec 的size
由于ViewRoot 的mPaddingBottom=100px(这个可能和状态栏的高度有关，我们测量的最后会发现id/statusBarBackground的View的高度刚好等于100px，ViewRoot 是系统的View的它的Padding 我们没法改变，所以计算出来Content（android.R.id.content） 的MeasureSpec 的高度少了100px ，它的宽高的mode 根据算出来也是EXACTLY（ViewRoot 是EXACTLY和android.R.id.content 是match_parent）。所以Content（android.R.id.content）的MeasureSpec 如下（高度少了100px）：
![image](https://upload-images.jianshu.io/upload_images/966283-5ce615a3684d7815.png)
Paste_Image.png
Content（android.R.id.content） 是FrameLayout，递归调用开始准备计算id/linear的MeasureSpec，我们先给出结果：
![image](https://upload-images.jianshu.io/upload_images/966283-c7e86f4510ddf84a.png)

> 图中有两个要注意的地方：
1、id/linear的heightMeasureSpec 的mode=AT_MOST，因为id/linear 的LayoutParams 的layout_height="wrap_content"
2、id/linear的heightMeasureSpec 的size 少了200px, 由上面的代码
padding=mPaddingTop + mPaddingBottom + lp.topMargin + lp.bottomMargin + heightUsed;
int size = Math.max(0, specSize - padding);
由于id/linear 的 android:layout_marginTop="50dp" 使得lp.topMargin=200px (本设备的density=4，px=4*pd)，在计算后id/linear的heightMeasureSpec 的size 少了200px。（布局代码前面已给出，可自行查看id/linear 控件xml中设置的属性）

linear.measure接着往下算linear的子View的的MeasureSpec，看下View 层级图，往下走应该是id/text,接下来是计算id/text的MeasureSpec，直接看图，mode=AT_MOST ,size 少了280，别问我为什么 ...specSize - padding.
![image](https://upload-images.jianshu.io/upload_images/966283-058c5a6ce57b3125.png)

算出id/text 的MeasureSpec 后，接下来text.measure(childWidthMeasureSpec, childHeightMeasureSpec);准备测量id/text 的高宽，这时候已经到底了，id/text是TextView，已经没有子类了，这时候跳到TextView的onMeasure方法了。TextView 拿着刚才计算出来的heightMeasureSpec（mode=AT_MOST,size=1980）,这个就是对TextView的高度和宽度的约束，进到TextView 的onMeasure(widthMeasureSpec,heightMeasureSpec) 方法，在onMeasure 方法执行调试过程中，我们发现下面的代码：

```

int desired = getDesiredHeight(); desired = 107px
if(heightMode == MeasureSpec.AT_MOST){
    height = Math.min(desired,heightSize); height = 1980px
   }
    setMeasuredDimension(width,height);


```


TextView字符的高度（也就是TextView的content高度[wrap_content]）测出来=107px，107px 并没有超过1980px(允许的最大高度)，所以实际测量出来TextView的高度是107px。
最终算出id/text 的mMeasureWidth=1440px,mMeasureHeight=107px。

贴一下布局代码，免得你忘了具体布局。

```
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout  xmlns:android="http://schemas.android.com/apk/res/android"    
   android:id="@+id/linear"
   android:layout_width="match_parent"    
   android:layout_height="wrap_content"    
   android:layout_marginTop="50dp"    
   android:background="@android:color/holo_blue_dark"    
   android:paddingBottom="70dp"    
   android:orientation="vertical">    
   <TextView        
    android:id="@+id/text"       
    android:layout_width="match_parent"     
    android:layout_height="wrap_content"  
    android:background="@color/material_blue_grey_800"       
    android:text="TextView"        
    android:textColor="@android:color/white"        
    android:textSize="20sp" />    
   <View       
      android:id="@+id/view"       
     android:layout_width="match_parent" 
     android:layout_height="150dp"    
     android:background="@android:color/holo_green_dark" />
</LinearLayout>
```

TextView的高度已经测量出来了，接下来测量id/linear的第二个child（id/view），同样的原理测出id/view的MeasureSpec.

![image](https://upload-images.jianshu.io/upload_images/966283-55810a48922ac8fe.png)
id/view的MeasureSpec 计算出来后，调用view.measure(childWidthMeasureSpec, childHeightMeasureSpec)的测量id/view的高宽，之前已经说过View measure的默认实现是


```
protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {    
  setMeasuredDimension(
  getDefaultSize(getSuggestedMinimumWidth(), widthMeasureSpec),            
  getDefaultSize(getSuggestedMinimumHeight(), heightMeasureSpec));
}
```

最终算出id/view的mMeasureWidth=1440px,mMeasureHeight=600px。

id/linear 的子View的高度都计算完毕了，接下来id/linear就通过所有子View的测量结果计算自己的高宽，id/linear是LinearLayout，所有它的高度计算简单理解就是子View的高度的累积+自己的Padding.
![image](https://upload-images.jianshu.io/upload_images/966283-b089fd286ca7fc05.png)

最终算出id/linear的mMeasureWidth=1440px,mMeasureHeight=987px。

最终算出id/linear出来后，id/content 就要根据它唯一的子View id/linear 的测量结果和自己的之前算出的MeasureSpec一起来测量自己的结果，具体计算的逻辑去看FrameLayout onMeasure 函数的计算过程。以此类推，接下来测量ViewRoot,然后再测量id/statusBarBackground,虽然不知道id/statusBarBackground 是什么，但是调试的过程中，测出的它的高度=100px, 和 id/content 的paddingTop 刚好相等。在最后测量DecorView 的高宽，最终整个测量过程结束。所有的View的大小测量完毕。所有的getMeasureWidth 和 getMeasureWidth 都已经有值了。Measure 分析到此为止，如有不懂，评论留言（简书：kelin）

# layout过程

```
mView.measure(childWidthMeasureSpec, childHeightMeasureSpec); 
......
mView.layout(0, 0, mView.getMeasuredWidth(), mView.getMeasuredHeight());
```


performTraversals 方法执行完mView.measure 计算出mMeasuredXXX后就开始执行layout 函数来确定View具体放在哪个位置，我们计算出来的View目前只知道view矩阵的大小，具体这个矩阵放在哪里，这就是layout 的工作了。layout的主要作用 ：根据子视图的大小以及布局参数将View树放到合适的位置上。

既然是通过mView.layout(0, 0, mView.getMeasuredWidth(), mView.getMeasuredHeight()); 那我们来看下layout 函数做了什么，mView肯定是个ViewGroup，不会是View,我们直接看下ViewGroup 的layout函数


```java
public final void layout(int l, int t, int r, int b) {    
   if (!mSuppressLayout && (mTransition == null || !mTransition.isChangingLayout())) {        
    if (mTransition != null) {            
       mTransition.layoutChange(this);        
    }       
    super.layout(l, t, r, b);    
    } else {        
    // record the fact that we noop'd it; request layout when transition finishes        
      mLayoutCalledWhileSuppressed = true;    
   }
}
```

代码可以看个大概，LayoutTransition是用于处理ViewGroup增加和删除子视图的动画效果，也就是说如果当前ViewGroup未添加LayoutTransition动画，或者LayoutTransition动画此刻并未运行，那么调用super.layout(l, t, r, b)，继而调用到ViewGroup中的onLayout，否则将mLayoutSuppressed设置为true，等待动画完成时再调用requestLayout()。
这个函数是final 不能重写，所以ViewGroup的子类都会调用这个函数，layout 的具体实现是在super.layout(l, t, r, b)里面做的，那么我接下来看一下View类的layout函数

 
```java
public final void layout(int l, int t, int r, int b) {
       .....
      //设置View位于父视图的坐标轴
       boolean changed = setFrame(l, t, r, b); 
       //判断View的位置是否发生过变化，看有必要进行重新layout吗
       if (changed || (mPrivateFlags & LAYOUT_REQUIRED) == LAYOUT_REQUIRED) {
           if (ViewDebug.TRACE_HIERARCHY) {
               ViewDebug.trace(this, ViewDebug.HierarchyTraceType.ON_LAYOUT);
           }
           //调用onLayout(changed, l, t, r, b); 函数
           onLayout(changed, l, t, r, b);
           mPrivateFlags &= ~LAYOUT_REQUIRED;
       }
       mPrivateFlags &= ~FORCE_LAYOUT;
       .....
   }
```

1、setFrame(l, t, r, b) 可以理解为给mLeft 、mTop、mRight、mBottom赋值，然后基本就能确定View自己在父视图的位置了，这几个值构成的矩形区域就是该View显示的位置，这里的具体位置都是相对与父视图的位置。

2、回调onLayout，对于View来说，onLayout只是一个空实现，一般情况下我们也不需要重载该函数,：


```java
protected void onLayout(boolean changed, int left, int top, int right, int bottom) {  

    }
```

对于ViewGroup 来说，唯一的差别就是ViewGroup中多了关键字abstract的修饰，要求其子类必须重载onLayout函数。


```
@Override  
protected abstract void onLayout(boolean changed,  
        int l, int t, int r, int b);
```

而重载onLayout的目的就是安排其children在父视图的具体位置，那么如何安排子View的具体位置呢？

 
```
int childCount = getChildCount() ; 
  for(int i=0 ;i<childCount ;i++){
       View child = getChildAt(i) ;
       //整个layout()过程就是个递归过程
       child.layout(l, t, r, b) ;
    }
```

代码很简单，就是遍历自己的孩子，然后调用 child.layout(l, t, r, b) ，给子view 通过setFrame(l, t, r, b) 确定位置，而重点是(l, t, r, b) 怎么计算出来的呢。还记得我们之前测量过程，测量出来的MeasuredWidth和MeasuredHeight吗？还记得你在xml 设置的Gravity吗？还有RelativeLayout 的其他参数吗，没错，就是这些参数和MeasuredHeight、MeasuredWidth 一起来确定子View在父视图的具体位置的。具体的计算过程大家可以看下最简单FrameLayout 的onLayout 函数的源码，每个不同的ViewGroup 的实现都不一样，这边不做具体分析了吧。

3、MeasuredWidth和MeasuredHeight这两个参数为layout过程提供了一个很重要的依据（如果不知道View的大小，你怎么固定四个点的位置呢），但是这两个参数也不是必须的，layout过程中的4个参数l, t, r, b完全可以由我们任意指定，而View的最终的布局位置和大小（mRight - mLeft=实际宽或者mBottom-mTop=实际高）完全由这4个参数决定，measure过程得到的mMeasuredWidth和mMeasuredHeight提供了视图大小测量的值，但我们完全可以不使用这两个值，所以measure过程并不是必须的。如果我们不使用这两个值，那么getMeasuredWidth() 和getWidth() 就很有可能不是同一个值，它们的计算是不一样的：

```java
public final int getMeasuredWidth() {  
        return mMeasuredWidth & MEASURED_SIZE_MASK;  
    }  
public final int getWidth() {  
        return mRight - mLeft;  
    }
```

layout 过程相对简单些，分析就到此为止。

# draw过程
performTraversals 方法的下一步就是mView.draw(canvas); 因为View的draw 方法一般不去重写，官网文档也建议不要去重写draw 方法，所以下一步执行就是View.java的draw 方法，我们来看下源码：


```java
public void draw(Canvas canvas) {
    ...
        /*
         * Draw traversal performs several drawing steps which must be executed
         * in the appropriate order:
         *
         *      1. Draw the background
         *      2. If necessary, save the canvas' layers to prepare for fading
         *      3. Draw view's content
         *      4. Draw children
         *      5. If necessary, draw the fading edges and restore layers
         *      6. Draw decorations (scrollbars for instance)
         */

        // Step 1, draw the background, if needed
    ...
        background.draw(canvas);
    ...
        // skip step 2 & 5 if possible (common case)
    ...
        // Step 2, save the canvas' layers
    ...
        if (solidColor == 0) {
            final int flags = Canvas.HAS_ALPHA_LAYER_SAVE_FLAG;

            if (drawTop) {
                canvas.saveLayer(left, top, right, top + length, null, flags);
            }
    ...
        // Step 3, draw the content
        if (!dirtyOpaque) onDraw(canvas);

        // Step 4, draw the children
        dispatchDraw(canvas);

        // Step 5, draw the fade effect and restore layers

        if (drawTop) {
            matrix.setScale(1, fadeHeight * topFadeStrength);
            matrix.postTranslate(left, top);
            fade.setLocalMatrix(matrix);
            canvas.drawRect(left, top, right, top + length, p);
        }
    ...
        // Step 6, draw decorations (scrollbars)
        onDrawScrollBars(canvas);
    }
```

注释写得比较清楚，一共分成6步，看到注释没有（ // skip step 2 & 5 if possible (common case)）除了2 和 5之外 我们一步一步来看：
1、第一步：背景绘制
看注释即可，不是重点

```
private void drawBackground(Canvas canvas) { 
     Drawable final Drawable background = mBackground; 
      ...... 
     //mRight - mLeft, mBottom - mTop layout确定的四个点来设置背景的绘制区域 
     if (mBackgroundSizeChanged) { 
        background.setBounds(0, 0, mRight - mLeft, mBottom - mTop);   
        mBackgroundSizeChanged = false; rebuildOutline(); 
     } 
     ...... 
     //调用Drawable的draw() 把背景图片画到画布上
     background.draw(canvas); 
     ...... 
}
```

2、第三步，对View的内容进行绘制。
onDraw(canvas) 方法是view用来draw 自己的，具体如何绘制，颜色线条什么样式就需要子View自己去实现，View.java 的onDraw(canvas) 是空实现，ViewGroup 也没有实现，每个View的内容是各不相同的，所以需要由子类去实现具体逻辑。

3、第4步 对当前View的所有子View进行绘制
dispatchDraw(canvas) 方法是用来绘制子View的，View.java 的dispatchDraw()方法是一个空方法,因为View没有子View,不需要实现dispatchDraw ()方法，ViewGroup就不一样了，它实现了dispatchDraw ()方法：


```
@Override
 protected void dispatchDraw(Canvas canvas) {
       ...
        if ((flags & FLAG_USE_CHILD_DRAWING_ORDER) == 0) {
            for (int i = 0; i < count; i++) {
                final View child = children[i];
                if ((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null) {
                    more |= drawChild(canvas, child, drawingTime);
                }
            }
        } else {
            for (int i = 0; i < count; i++) {
                final View child = children[getChildDrawingOrder(count, i)];
                if ((child.mViewFlags & VISIBILITY_MASK) == VISIBLE || child.getAnimation() != null) {
                    more |= drawChild(canvas, child, drawingTime);
                }
            }
        }
      ......
    }
```

代码一眼看出，就是遍历子View然后drawChild(),drawChild()方法实际调用的是子View.draw()方法,ViewGroup类已经为我们实现绘制子View的默认过程，这个实现基本能满足大部分需求，所以ViewGroup类的子类（LinearLayout,FrameLayout）也基本没有去重写dispatchDraw方法，我们在实现自定义控件，除非比较特别，不然一般也不需要去重写它， drawChild()的核心过程就是为子视图分配合适的cavas剪切区，剪切区的大小正是由layout过程决定的，而剪切区的位置取决于滚动值以及子视图当前的动画。设置完剪切区后就会调用子视图的draw()函数进行具体的绘制了。

4、第6步 对View的滚动条进行绘制
不是重点，知道有这东西就行，onDrawScrollBars 的一句注释 ：Request the drawing of the horizontal and the vertical scrollbar. The scrollbars are painted only if they have been awakened first.

一张图看下整个draw的递归流程。



到此整个绘制过程基本讲述完毕了。

