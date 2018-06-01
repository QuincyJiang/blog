
title: Java垃圾回收策略（二）
date: 2018/05/23 16:56:50
categories: java基础
comments: true
tags: [java,垃圾回收]
上文说到了一个java对象的生命周期以及生存位置
本文主要讲 jvm虚拟机如何判定一个对象是否是垃圾，以及以何种算法回收垃圾。
## GC的工作流程
### 1. 判定那些对象已成为垃圾
jvm一般有两种方法判断对象是否成为垃圾
#### 1. 引用标记算法
##### 1.流程
1. 给每一个对象都增加一个引用计数器
2. 每次对象新增一个引用的时候，该计数器+1
3. 当该引用对象失效（比如超出了作用域）==【注1】==，该引用计数器-1
4. 当该对象的引用计数器为1时，表明该对象不可用，可作为垃圾回收了。
> 注1：
作用域的概念，上文其实已经说过了，见
[JAVA垃圾回收机制](http://wenyiqingnian.xyz/2018/05/17/JAVA%E7%9A%84%E5%9E%83%E5%9C%BE%E5%9B%9E%E6%94%B6%E7%AD%96%E7%95%A5/)。当在方法内创建了一个引用变量并指向它引用的对象的时候，引用的对象会在方法执行完后仍然存活在堆内存上，只是引用变量会随方法一起出栈销毁而已，见下面的例子。

```java
void fun(){
...
Persion p = new Person();
}
/**
*方法之外，引用变量P就消失了，因为引用变量是存放在
*方法栈中的，所以方法执行完毕，p便随着方法栈一起出
*栈，但是因为这中间调用了new 关键字,其创建的person对象会一直存放在堆内存中等待**被GC，此时person对象，就是超出了作用域的对象。
*/
```


```
graph LR
CLASS_A-->CLASS_B
CLASS_B-->CLASS_A
```

##### 2. 引用标记算法的优缺点
* 优点：算法简单，执行速度快，不需要长时间中断应用程序的执行
* 缺陷：无法解决循环引用问题（A引用B，B引用A，此时引用计数器永远无法置0）。
#### 2. GC_ROOT 可达性算法
##### 1. 原理
1. 以GC root作为根节点 ==（gcroot具体包含那些对象下面会详细解释）==,向下搜寻所有对象
2. 如果可以走到该对象，就建立一个该对象和GCTROOT之间的引用链。
3. 从根节点开始，生成对象引用树，不可达的对象，会被判断为垃圾由GC判断是否回收


```
graph LR
GCROOT-->CLASS_A
GCROOT-->CLASS_B
GCROOT-->CLASS_C
GCROOT-->CLASS_E
CLASS_A-->CLASS_D
CLASS_A-->CLASS_F
CLASS_B-->CLASS_F
CLASS_B-->CLASS_G
CLASS_H-->CLASS_J
CLASS_J-->CLASS_H
CLASS_E-->CLASS_K

```
上图的对象h和对象j 就是不可达的引用，但是彼此持有对方的引用，如果用引用计数算法，该对象是无法被回收的，gcroot算法，他们是不可达的，会随时被gc回收。



#### 3.关于回收的一些其他问题
当对象被标记为不可达的时候，gc并不会立刻启动回收程序，而是再使用两次标记算法来区分何时回收。
在GC启动回收程序的时候，为了保证引用状态不变，系统会暂停所有应用进程（stopt the world ），这个时间很短，反应在UI上就是UI卡顿了一下，所以安卓应用要十分注意合理控制好内存回收，不要频繁处罚GC，不然体验会十分糟糕。

> 二次标记算法:
1.如果对象与GC Root没有连接的引用链，就会被第一次标记，随后判定该对象是否有必要执行finalize()方法

> 2.如果有必要执行finalize()方法，则这个对象就会被放到F-Queue的队列中，稍后由虚
拟机建立低优先级的Finalizer线程去执行，但并不承诺等待它运行结束（对象类中能够
重写finalize()方法进行自救，但系统最多只能执行一次）

> 3.如果没必要执行finalize()方法，则第二次标记


#### 2. 通过特定算法回收垃圾
主要包括以下四种算法

```
1、标记清除算法
2、算法算法
3、标记整理算法
4、分代回收算法
```
##### 1. 标记清除算法
两步走
* 标记 标记出无用的对象
* 清除 清除掉对象的空间
![image](https://upload-images.jianshu.io/upload_images/715464-fc0e522c2f77c4ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/540)
可以看到 优缺点很明显

 
```
缺点：容易造成内存碎片，当下次申请大内存的时候，可能找不到连续的内存给其使用，会频繁出发gc，

优点：是算法比较简单。
```


因为标记无用对象耗时，可以看出 标记清除算法比较适合于 垃圾少，存活对象多的情况，可以减少标记次数。在分代回收算法中，它一般应用在老年代（对象存活率高，需要回收的少）

##### 2. 复制算法（也被成为拷贝回收算法）
此方法将内存按容量分为两块，例如A、B两块，每次只使用其中的一块，当要进行回收操作时，将A中还存活的对象复制到B块中（假设上次使用A），然后对A中所有对象清空就又构成一个完整的内存块。这种方法就避免了标记清除的内存碎片问题。
![image](https://upload-images.jianshu.io/upload_images/715464-dc608f70f2c1decd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/511)



```
优点：不会产生内存碎片

缺点： 会浪费内存，因为不管A块中有多少存活对象，都只能使用内存的一半，AB块中始终有一块为空，属于用空间换时间。 分代回收法中新生代的部分，使用的是该算法。

```
适合存活对象少 回收对象多的情况，因为存活对象多复制的过程就长一些，算法效率会受影响。

##### 3. 标记整理算法

解决了上述两种算法的缺点，但也带来了新的缺点，就是算法效率不够高。

```
1. 标记存活对象
2. 移动对象到左上角
3. 将其他空间全部回收
```


```
优点： 不会产生内存碎片 不会造成空间使用浪费

缺点：标记的过程导致其效率不如复制算法，移动的过程，导致其效率不如标记算法。
```
![image](https://upload-images.jianshu.io/upload_images/715464-59e3d36bee590be1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/679)

适合存活对象多


##### 4. 分代回收算法

该算法其实是上述三种算法的组合，因为上述三种算法都有其适用的适用情景，不可能适用所有情况，分代回收算法就是根据jvm里不同对象的存活特性来组合使用上述三种算法。

jvm按照对象生命周期将内存划分为两个区域。
* **新生代** 

新生代会产生大量的临时对象。这些对象 朝生夕死。存活时间短，经常需要回收，所以采用拷贝回收算法。在新生代的gc，称之为**minor gc**。
* **老年代** 

一般是生命周期长的对象，回收频率很低，只有当老年代内存占满了之后，才会触发一次full gc，或称之为（major gc）。

内存的具体划分

![image](https://pic4.zhimg.com/80/v2-2a4b12f1a7633839bd1c5bdae358f9ba_hd.jpg)

可以看到 

新生代又被分为Eden 区 和 s1，s2区。s1 s2是为了拷贝算法划分的乒乓区域。他们大小是相同的。
##### 2. 分代回收算法的具体回收过程
 1. 新生对象全部在Eden区域活动，当Eden区域满了之后，会触发一次minor gc  将Eden区域中还能用的的对象拷贝到From区域。
 ![image](https://img-blog.csdn.net/20161101200530361)
此时 Eden区域的空间被清空，存活对象在From区。
 2. 当From区域满了之后，会再次触发monor gc，将Eden和From区域中还可用的对象拷贝到To区域中。
 ![image](https://img-blog.csdn.net/20161101200709299)
此时 Eden 和From区的空间被清空。

3. 当To的空间满了之后，会再次触发minor gc，此时会将Eden 和To 空间中还存活的对象拷贝到From区。Eden 和To space被清空。
![image](https://img-blog.csdn.net/20161101200920951)

4. 在多次minor gc之后，有些对象会一直在from和to 区域之间来回拷贝，此时会被算法标注为老年代对象，gc会将该对象从新生代直接拷贝到老年代。
 JVM虚拟机默认的反复拷贝次数为==15次==。如果对象在From 到 to区域中反复拷贝了15次，就会被划分为老年代。
![image](https://img-blog.csdn.net/20161101201239084)
5. 对象进入老年代之后，当老年代内存区域也满了，便会触发一次Full gc， 此时使用的算法是标记算法和标记整理算法。
6. 为什么老年代的gc 不使用拷贝算法，因为老年代中的对象大多是存活率高的对象，使用拷贝算法要创建一个很大的新内存空间来做拷贝，这样很浪费资源。为什么不只使用标记算法，因为这样会导致内存碎片。使用标记清除算法，会将存活对象做地址移动，都集中在一块连续地址空间中，防止产生内存碎片。
7. 所monor gc的时候，是用空间换时间，因为该gc发生频繁，效率是首要考虑的问题。 而full gc的时候，腾出空间更重要，所以选择用时间（使用标注整理算法）换空间。

##### 3. 新生代老年代的内存划分比

新生代：老年代 2：1

新生代中

Eden : s1 : s2  = 8 : 1 : 1

### 3. GC_ROOT

要记住一个概念，选gcroot，就是要以这些当前活跃的gcroot对象为根去遍历所有引用关系，能遍历到的就是存活的，遍历不到的认为死去，所以选gcroot，本质是找到==所有存活的对象==，把其他空间认定为无用去清除掉。
所以gcroot必须具备两个性质
 1. 必须存活
 2. 必须有其他引用（因为要以它自己去遍历引用关系）

![image](https://images2015.cnblogs.com/blog/975131/201607/975131-20160715211141123-1331326167.png)
jvm 运行时内存


所以“GC roots”，或者说tracing GC的“根集合”，就是一组必须==活跃==的==引用==。
具体包括以下几种：

```java 
1. Class 由System Class Loader/Boot Class Loader加载的类，类似于java.util.*包下的类，因为它
一定是贯穿于整个生命周期的，可以以此为根遍历出去找到其他引用的类。被引用到的就一定是存活的。
2. Thread 对象，已激活但是未结束的线程对象；
3. Stack Local 栈中的对象。每个线程都会分配一个栈，栈中的局部变量或者参数的引用都是GC root，因为仍在栈中，表明方法还没执行完，对象仍存活，（执行后的方法会出栈，就不满足存活条件了），同时是引用对象。
4.JNI Local JNI中的局部变量和参数引用的对象；可能在JNI中定义的，也可能在虚拟机中定义
5. JNI Global JNI中的全局变量引用的对象；同上
6. Monitor Used 用于保证同步的对象，例如wait()，notify()中使用的对象、锁等。
7. Held by JVM JVM持有的对象。JVM为了特殊用途保留的对象，它与JVM的具体实现有关。比如有System Class Loader, 一些Exceptions对象，和一些其它的ClassLoader。对于这些类，JVM也没有过多的信息。
8. 静态数据结构指向对象堆的引用。

```

关于1 2 我举几个具体例子来说明一下：

```java
//1.由系统类加载器加载的类
public class ServiceManager extends Service {
    public Person p = new Person();
}
这里不确切，但是大致可以表明意思，安卓
ServiceManager贯穿整个应用生命周期，它里面持有Persion对象的引用，这个ServiceManager对象就是gcroot 它持有的person对象永远不会被释放。

2. //Thred Local

public class A{
  
  void main(){
      Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                B b = new B();
            }
        });
        
        t.start();
  }
    
}

t 属于gcroot 如果不停止thread t永远不会被回收，它持有的b 也不会被回收。

3.

```

> ==注意，是一组必须活跃的引用，不是对象==
Tracing GC的根本思路就是：给定一个集合的引用作为根出发，通过引用关系遍历对象图，能被遍历到的（可到达的）对象就被判定为存活，其余对象（也就是没有被遍历到的）就自然被判定为死亡。注意再注意：tracing GC的本质是==通过找出所有活对象来把其余空间认定为“无用”==，而不是==找出所有死掉的对象并回收它们占用的空间==。这里非常容易搞混淆！！GC roots这组引用是tracing GC的起点。
### 4 . 安卓的Dalvik虚拟机与jvm不同的地方

#### 1. 堆的结构不同
  Dalvik虚拟机用来分配对象的堆划分为两部分，一部分叫做**Active Heap**，另一部分叫做**Zygote Heap**。为什么要划分为两个堆，是为了减少内存拷贝的过程。(5.0之后改为ART虚拟机，ART运行时堆划分为四个空间，分别是Image Space、Zygote Space、Allocation Space和Large Object Space)
  
  
```
graph LR
ActiveHeap
ZygoteHeap
```

  我们知道 安卓系统的父进程是Zygote进程，它在开机的过程中就为Android系统准备好了一个Dalvik虚拟机实例。
  
  安卓的每一个应用程序都是一个独立的进程，都有自己独立的内存空间和虚拟机实例，如果在应用启动的时候都重新为其创建虚拟机实例，是十分消耗资源的，为了加快这个速度，dalvik虚拟机采用写时拷贝的方式，将Zygote进程在开机时就创建好的Dalvik虚拟机实例，复制到应用程序的进程中去，从而加快了Android应用程序进程的启动过程。
  
  因为zygote进程作为核心进程，应用的虚拟机实例都是复制于它，在创建虚拟机实例的时候，要预先加载安卓系统的核心方法还有一些核心类，是重量级的进程。主要做了以下四件事情：
```
1. 创建了一个Dalvik虚拟机实例；
2. 加载了Java核心类及其JNI方法；
3. 为主线程的设置了一个JNI环境；
4. 注册了Android核心类的JNI方法。
```
这些核心类可以与应用程序共享，所以说
 zygote牺牲自己的启动时间，来提高应用的加载速度。
  
  但拷贝仍然是很费时的操作，为了避免拷贝，dalvik将自己的堆分为两部分，事实上，Dalvik虚拟机的堆最初是只有一个的。也就是Zygote进程在启动过程中创建Dalvik虚拟机的时候，只有一个堆。但是当Zygote进程在fork第一个应用程序进程之前，会将已经使用了的那部分堆内存划分为一部分，还没有使用的堆内存划分为另外一部分。前者就称为Zygote堆，后者就称为Active堆。以后无论是Zygote进程，还是应用程序进程，当它们需要分配对象的时候，都在Active堆上进行。
  
  
 > zygote堆  zygote进程启动创建虚拟机的时候已经用了的那部分内存，主要存的是Zygote进程在启动过程中预加载的类、资源和对象
 
 > active堆  zygote启动创建虚拟机时尚未使用的堆内存。应用程序还有zygote进程创建对象都在该堆进行
  
  这样就可以使得Zygote堆尽可能少地被执行写操作，因而就可以减少执行写时拷贝的操作，在zygote堆中存放的预加载的类、资源和对象可以在Zygote进程和应用程序进程中做到长期共享。这样既能减少拷贝操作，还能减少对内存的需求。
  #### 2.标记机制不同
  虽然dalvik虚拟机也是用的标记-清除算法，但为了减少Stop_the_world 造成的停顿，采用的并行垃圾回收算法（Concurrent GC）
  标记被分为两部分
  1. 第一步 只标记gcroot 引用的对象 
  2. 第二步 标记被gcroot 引用对象所引用的其他对象
例如，一个栈变量引了一个对象，而这个对象又通过成员变量引用了另外一个对象，那该被引用的对象也会同时标记为正在使用。这个标记被根集对象引用的对象的过程就是第二个子阶段。

**注意**

> 在Concurrent GC，第一个子阶段是不允许垃圾收集线程之外的线程运行的，但是第二个子阶段是允许的。不过，在第二个子阶段执行的过程中，如果一个线程修改了一个对象，那么该对象必须要记录起来，因为它很有可能引用了新的对象，或者引用了之前未引用过的对象。如果不这样做的话，那么就会导致被引用对象还在使用然而却被回收。这种情况出现在只进行部分垃圾收集的情况，这时候Card Table的作用就是用来记录非垃圾收集堆对象对垃圾收集堆对象的引用。


### 4. 由垃圾回收机制引申的内存泄漏问题

所谓内存泄漏，其实就是该回收的对象无法回收，造成无法回收的原因就是它还被gcroot直接或者间接引用。

可以看几个内存泄漏的例子

1. 静态类
```java
public class A {
    public static Context instance;
    public A(Context context){
        this.instance = context;
    }
}
```
静态成员变量 instance 持有一个context的引用，instance是gcroot，不会被回收，它持有的context对象也不会被回收，导致内存泄漏。

2. 匿名内部类

创建HashMap的时候，

```java
public class A {
    public static List<HashMap<String,Object>> list = new ArrayList<>();
}

```
属于匿名创建，list中会持有外部类的引用，list又是一个gcroot，导致类A 无法被回收，另一个常见的例子：
```java
public class MainActivity extends AppCompatActivity {
    private static MyHandler handler = new MyHandler();
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    public class MyHandler extends Handler {
        @Override
        public void handleMessage(Message msg) {
            super.handleMessage(msg);

        }
    }
}

```
静态成员变量handler指向Myhandler()，是GCROOT成员，但MyHandler是内部类，持有外部类MainActivity的引用，会导致MainActivity 无法被回收。

3. 线程未结束
```java
public class MainActivity extends  MainActivity {
  
  void foo(){
      Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                Activity a = MainActivity.this;
                ...
                ...
            }
        });
        
        t.start();
  }
    
}
```

如果t不执行完，Activity1就无法被回收。

4. JNI LOCAL GLOBAL reference
这类对象一般发生在参与Jni交互的类中。

比如说很多close()相关的类，InputStream,OutputStream,Cursor,SqliteDatabase等。这些对象不止被Java代码中的引用持有，也会被虚拟机中的底层代码持有。在将持有它们的引用设置为null之前，要先将他们close()掉。
还有一个特殊的类是Bitmap。在Android系统3.0之前，它的内存一部分在虚拟机中，一部分在虚拟机外。因此它的一部分内存不参与垃圾回收，需要我们主动调用recycler()才能回收。

动态链接库中的内存是用C/C++语言申请的，这些内存不受虚拟机的管辖。所以，so库中的数组，类等都有可能发生内存泄漏，使用的时候务必小心。
