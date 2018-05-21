title: AnimatedVectorDrawable总结
date: 2018/05/10 00:51:50
categories: CoolUI
comments: true
tags: [句柄animation,AnimatedVectorDrawable]
---
在更新Android N之后 会注意到状态栏上的快捷方式有了新的变化 当我们点击的时候，从开启到关闭状态，会有一个顺滑自然的过渡动画，在学习完AnimatinVectorDrawable的api用法之后，你就会知道该怎么实现这些类似的效果了。

## Vector
在开始之前，想先说明一下安卓中的矢量图标文件**Vector**
，我们经常会用到矢量图，将一张SVG的图片通过AS自动生成一个以vector为根节点的xml文件，可以直接通过
```
R.drawable.xx
```
的格式引用它。矢量图形不管我们如何拉伸都不会模糊，因此广受开发者青睐。
看一下一个典型的**vector**文件结构


```xml
<vector android:height="24dp" 
android:viewportHeight="24dp"
    android:viewportWidth="24" 
    android:width="24" 
    xmlns:android="http://schemas.android.com/apk/res/android">
    <path 
        android:fillColor="#36ab60" 
        android:pathData="M6.4,6.4 L17.6,17.6 M6.4,17.6 L17.6 ,6.4"
        android:strokeWidth="2"
        android:strokeColor="#999"
        android:trimPathStart="0.1"
        android:trimPathEnd="0.9"/>
</vector>
```


* heigit/width: 图片的宽高
* viewportWidth/viewportHeight: 画布宽高，也是必填的，定义Path路径的时候就必须在这个画布大小里去绘制，超出画布就显示不出来了。
* path 绘制路径 主要理解几个字母代表的意思

```json
M：MOVE 将画笔移动到该点
L: LINE 直线连接到该点
C: CURVE  曲线连接到该点
Z: CLOSE  闭合曲线
```
* strokeWidth: 线的粗细
* trimPathStart: 绘制线段起始点偏移的百分比 
* 
 这么说起来其实有点抽象，用一张图来解释会更加直观一些
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/A201CE3001F34F0E93FA08F8F18FB8D9/3433)


```xml
android:trimPathStart="0"
android:trimPathEnd="1"/>
```

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/437E587CB9704EDF953BFE1F60CDD79F/3436)
```xml
android:trimPathStart="0"
android:trimPathEnd="0.75"/>
```
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/073C2DBFC90C4B959DE5BB2CA7343E7F/3434)
```xml
android:trimPathStart="0.5"
android:trimPathEnd="0.75"/>
```
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/FA0FF500CEAD4F5EA9B19DFC8430BF14/3435)
```xml
android:trimPathStart="0.25"
android:trimPathEnd="0.75"
android:trimPathOffset="0.25"/>
```
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/58466D2A0A82463C8BB0AA3C7FCF715C/3438)
```xml
android:trimPathStart="0.25"
android:trimPathEnd="0.75"
android:trimPathOffset="0.375"/>
```
其实这几张图片连在一起看，你会发现只要将这几个数值重复循环，这就成了一个进度条动画了。
下面正式讲解文章主角 
## AnimatedVectorDrawable

听名字其实可以猜到，它主要是靠两个东西来实现的
* ObjectAnimation
> 属性动画：
不用于补间动画，属性动画是直接对view的属性值进行动态、更改，不再只是一种视觉上的动画效果了。它实际上是一种不断地对值进行操作的机制，并将值赋值到指定对象的指定属性上，可以是任意对象的任意属性。关于属性动画的具体介绍不在本文重点，可以参考郭林的博客，[属性动画完全解析](https://blog.csdn.net/guolin_blog/article/details/43536355)
* VectorDrawable
> 矢量图型，上文已经介绍过，不再详述

#### 创建一个AnimatedVectorDrawable 
##### 定义一个vectorDrawable

```xml
android:drawable="@drawable/foo"
```

#### 创建一个animation

```xml
<ObjectAnimator
    android:propertyName="rotation"
    android:valueFrom="0"
    android:valueTo="180"
    android:duration="200"
    android:interpolator="@interpolator/..."
    android:valueType="floatVaule"
```
* valueFrom
* valueTo 
* propertyName: 要进行变换的属性值
该值有以以下几种取值 

```
Paths:(support-library 25.3以上 支持变换path数据)
Color:
Opacity:
Trim start /end /offset
Path:


Groups:
Translate:
Scale:
Rotate:
```
### paths分组下 
我们可以对颜色 不透明度 起始点偏移量 还有path元数据进行变换

#### 动画1

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/36520B59B24E40309D3F34AA4925F3A1/3505)

这是通过动态变换paths分组下的start end的偏移位置，做到x变为对号，同时通过groups分组下的
translate 来动态改变位置图像在变化前后还保持中心位置


其实通过trim属性，我们可以做到更多炫酷的动画效果，可以先看下面这个动画

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/1AD156AC9EFE4D7BAA9CB4E3EF8D04E4/3520)

它的完整路径其实是这样的

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/D1E2710E1D8146ECBBE830E7A12B6FF1/3523)

只是通过变换trim的值，让其部分不可见便实现了上述效果

### 动画2

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/AA8F9653DD2E477EAA021A2FCC4098A9/3577)

本质是将碎裂的心分为两组图片，心的填充颜色默认为白色，点击填充是更改了透明度opacity，裂开的动画是使用groups中的rotation动画



## Path Morphing
我们还可以直接对path元数据进行变换 

```xml
<ObjectAnimator
    android:propertyName="pathData"
    android:valueFrom="M6.4,6.4 L17.6,17.6 M6.4,17.6 L17.6 ,6.4"
    android:valueTo="M6,10 L4,10 ..."
    android:duration="200"
    android:valueType="pathType"
    ...
```

**但进行path变换的前提是**
**前后两条path路径 他们的绘制点数量和绘制命令必须是相同的
就比如上面代码中 变换前是4个点 变换后也必须是四个点 而且 m l m l 的顺序不可以改变**

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/BFFB93AAA87E44B8A9B4A5CA7208BBA6/3579)

上面这种 两个正方形 大小变了 形状没变，我们可以选定点的四个点作为变换参考点，只需要改变下四个点的前后坐标就可以了，绘制流程是不变的，符合要求，但如果变换前后是这样的呢？
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/61824E98C71D434E922CF7AEE414E4C1/3581)

圆是没有顶点的，这时候只能变通一下，这样来选择四个点，同时要将连接点与点之间的命令由L （直线）改为C（曲线），这样可以通过控制贝塞尔曲线的控制点坐标，达到绘制圆弧和直线的效果。
你可以通过设置更多的控制点 来达到更顺滑的变换效果

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/A2A9FA92731B4B9CA42B965207475945/3583)


进行path变换 因为要操作控制点坐标，也带来了下面几个问题
#### 1.无法精确获取点的坐标
我们绘制的矢量图 一般用的是sketch之类的软件，
它并不能让我们直接选择变换的点，比如上面的圆，只能得到一个半径和圆心坐标，无法精准的获取四个或者更多控制点的坐标
#### 2.点与点之间无法重叠
#### 3.不能直观的看到动画中间状态的样子
有时候点选择的不合理，会导致变换中间产生一些非常奇怪的形状，类似sketch之类的设计工具并不能直观看到变化中间态的样子

幸运的是 有个工具可以很好解决上述的三个问题

是一个在线预览工具，[shapeshafter](https://shapeshifter.design/)

官方的详细介绍 [在这里](http://www.androiddesignpatterns.com/2016/11/introduction-to-icon-animation-techniques.html)
我这边以创建一个-号到+号的变换动画为例，简单介绍下用法

##### 1. 上传两张svg图片
分别表示的是变换前，变换后
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/WEBRESOURCE3158c893d5e0815abb83b97b2b4def10/3588)

#### 2.复制第二个涂层的pathdata后，删除该图层
![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/WEBRESOURCE060f9ae7adf7ce1c99f4c524c29d86fd/3589)

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/WEBRESOURCE61d5eb6a60bea13e3c6a8aef6bc538e2/3590)

#### 3. 调整第一张图，选择要变换的数据是pathdata，并将变化后 也即第二张图的pathdata 粘贴进去

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/WEBRESOURCEb4fda6557ac02bfd5d6ac837eb1fe426/3593)

这时候因为“+”和“-”的节点数不一致，会报错提示，可以点击修改pathdata 按钮去手动删减增加一些节点数据

![image](https://note.youdao.com/yws/public/resource/fa0a00bd4972d5802d8ad504e9e623fc/xmlnote/WEBRESOURCE72cbd215442bfa5a09c6f4dedffa16d8/3596)

#### 4.妥善选择好前后的节点位置，就可以点击下方播放按钮直观查看变化效果了，不满意可以修改节点，知道达到预期目标。

----
>待续
>
>-----------------18.5.9